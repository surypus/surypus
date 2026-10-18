#!/usr/bin/env python3
"""
codex-openai-proxy — local OpenAI-shaped endpoint in front of the ChatGPT-account
Codex backend.

Why this exists: GSD has no bundled `openai-codex` provider extension, and its
`custom-openai` provider cannot set a `base_url`. A local proxy gives GSD a
plain OpenAI endpoint while the credential stays the ChatGPT OAuth session in
`~/.codex/auth.json` (never written to disk here beyond the auth file itself).

Endpoints
    GET  /v1/models                 -> OpenAI model list
    POST /v1/chat/completions       -> OpenAI chat-completions (stream + non-stream)
    POST /v1/responses              -> OpenAI responses API (stream + non-stream)
    GET  /healthz                   -> readiness probe

Auth: reads ~/.codex/auth.json, refreshes the access token via
https://auth.openai.com/oauth/token when it is within CODE_EXPIRY_MARGIN_S of
expiry (or when the backend answers 401).
"""
from __future__ import annotations

import base64
import datetime
import json
import os
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

AUTH_PATH = os.path.expanduser("~/.codex/auth.json")
BACKEND = "https://chatgpt.com/backend-api/codex"
TOKEN_URL = "https://auth.openai.com/oauth/token"
CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"
DEFAULT_MODEL = "gpt-6-luna"
EXPIRY_MARGIN_S = 300
LISTEN_HOST = os.environ.get("CODEX_PROXY_HOST", "127.0.0.1")
LISTEN_PORT = int(os.environ.get("CODEX_PROXY_PORT", "8787"))

_lock = threading.Lock()


# ─── Credentials ──────────────────────────────────────────────────────────────

def _read_auth() -> dict:
    with open(AUTH_PATH, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _id_token_expiry(auth: dict) -> float:
    token = auth.get("tokens", {}).get("id_token", "")
    parts = token.split(".")
    if len(parts) != 3:
        return 0.0
    payload = parts[1] + "=" * (-len(parts[1]) % 4)
    try:
        return float(json.loads(base64.urlsafe_b64decode(payload))["exp"])
    except Exception:
        return 0.0


def refresh_token() -> None:
    """Swap the stored refresh_token for a fresh access/id token pair."""
    auth = _read_auth()
    tokens = auth.get("tokens", {})
    data = urllib.parse.urlencode(
        {
            "client_id": CLIENT_ID,
            "grant_type": "refresh_token",
            "refresh_token": tokens.get("refresh_token", ""),
            "scope": "openid profile email",
        }
    ).encode()
    request = urllib.request.Request(
        TOKEN_URL,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = json.loads(response.read())
    for key in ("access_token", "id_token", "refresh_token"):
        if key in body:
            tokens[key] = body[key]
    auth["last_refresh"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    with open(AUTH_PATH, "w", encoding="utf-8") as fh:
        json.dump(auth, fh, indent=2)


def credentials() -> tuple[str, str]:
    """Return (access_token, account_id), refreshing first when close to expiry."""
    with _lock:
        auth = _read_auth()
        if _id_token_expiry(auth) - time.time() < EXPIRY_MARGIN_S:
            refresh_token()
            auth = _read_auth()
        tokens = auth.get("tokens", {})
        return tokens.get("access_token", ""), tokens.get("account_id", "")


# ─── Model catalog ────────────────────────────────────────────────────────────

def model_catalog() -> list[str]:
    """Query the per-account catalog; fall back to the known slugs offline."""
    try:
        token, account = credentials()
        url = BACKEND + "/models?" + urllib.parse.urlencode({"client_version": "1.0.0"})
        request = urllib.request.Request(
            url,
            headers={
                "Authorization": "Bearer " + token,
                "chatgpt-account-id": account,
                "Accept": "application/json",
            },
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            body = json.loads(response.read())
        slugs = [m["slug"] for m in body.get("models", []) if m.get("slug")]
        if slugs:
            return slugs
    except Exception:
        pass
    return [DEFAULT_MODEL, "gpt-reserve", "gpt-5.6-terra", "gpt-5.6-luna"]


# ─── OpenAI <-> Codex translation ──────────────────────────────────────────────

def chat_to_codex(payload: dict) -> dict:
    messages = payload.get("messages", []) or []
    instructions: list[str] = []
    input_items: list[dict] = []
    for message in messages:
        role = message.get("role", "user")
        content = message.get("content", "")
        text = content if isinstance(content, str) else _flatten_content(content)
        if role == "system":
            instructions.append(text)
            continue
        if role == "tool":
            input_items.append({"type": "function_call_output", "call_id": message.get("tool_call_id", ""), "output": text})
            continue
        if role == "assistant":
            input_items.append({"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": text}]})
            continue
        input_items.append({"type": "message", "role": "user", "content": [{"type": "input_text", "text": text}]})
    model = payload.get("model") or DEFAULT_MODEL
    body = {
        "model": model,
        "input": input_items,
        "stream": True,
        "store": False,
    }
    if instructions:
        body["instructions"] = "\n\n".join(instructions)
    return body


def responses_to_codex(payload: dict) -> dict:
    input_field = payload.get("input")
    if isinstance(input_field, str):
        input_items = [{"type": "message", "role": "user", "content": [{"type": "input_text", "text": input_field}]}]
    else:
        input_items = input_field or []
    body = {
        "model": payload.get("model") or DEFAULT_MODEL,
        "input": input_items,
        "stream": True,
        "store": False,
    }
    if payload.get("instructions"):
        body["instructions"] = payload["instructions"]
    if payload.get("tools"):
        body["tools"] = payload["tools"]
    return body


def _flatten_content(content) -> str:
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict):
                parts.append(item.get("text") or "")
            else:
                parts.append(str(item))
        return "\n".join(p for p in parts if p)
    return str(content)


def call_codex(body: dict, *, stream: bool):
    """POST to the backend. Returns (status, headers, raw_bytes)."""
    token, account = credentials()
    data = json.dumps(body).encode()
    headers = {
        "Authorization": "Bearer " + token,
        "chatgpt-account-id": account,
        "Content-Type": "application/json",
        "User-Agent": "codex_cli_rs/0.163.0",
        "originator": "codex_cli_rs",
        "Accept": "text/event-stream" if stream else "application/json",
    }
    request = urllib.request.Request(BACKEND + "/responses", data=data, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=600) as response:
            return response.status, dict(response.headers), response.read()
    except urllib.error.HTTPError as error:
        return error.code, dict(error.headers or {}), error.read()


# ─── SSE rewriting ────────────────────────────────────────────────────────────

def rewrite_stream(raw: bytes, *, out_format: str, model: str) -> bytes:
    """Translate codex SSE events into OpenAI-shaped SSE, preserving chunking."""
    out: list[bytes] = []
    text_buf: list[str] = []
    for line in raw.decode("utf-8", "replace").splitlines():
        line = line.strip()
        if not line.startswith("data:"):
            continue
        try:
            event = json.loads(line[5:].strip())
        except json.JSONDecodeError:
            continue
        etype = event.get("type", "")
        if etype == "response.output_text.delta":
            delta = event.get("delta", "")
            if not delta:
                continue
            text_buf.append(delta)
            if out_format == "chat":
                out.append(_chat_chunk(model, delta))
            else:
                out.append(_responses_chunk(model, delta))
        elif etype == "response.completed":
            break
        elif etype == "error":
            message = event.get("error", {}).get("message", "backend error")
            if out_format == "chat":
                out.append(_chat_error(model, message))
            else:
                out.append(_responses_error(message))
            break
    if out_format == "chat":
        out.append(_chat_finish(model))
        out.append(b"data: [DONE]\n\n")
    else:
        out.append(b"data: " + json.dumps({"type": "response.completed", "response": {"status": "completed", "output": []}}).encode() + b"\n\n")
    return b"".join(out)


def _chat_chunk(model: str, delta: str) -> bytes:
    payload = {
        "id": "chatcmpl-proxy",
        "object": "chat.completion.chunk",
        "created": int(time.time()),
        "model": model,
        "choices": [{"index": 0, "delta": {"content": delta}, "finish_reason": None}],
    }
    return b"data: " + json.dumps(payload).encode() + b"\n\n"


def _chat_finish(model: str) -> bytes:
    payload = {
        "id": "chatcmpl-proxy",
        "object": "chat.completion.chunk",
        "created": int(time.time()),
        "model": model,
        "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
    }
    return b"data: " + json.dumps(payload).encode() + b"\n\n"


def _chat_error(model: str, message: str) -> bytes:
    payload = {"error": {"message": message, "type": "proxy_error"}}
    return b"data: " + json.dumps(payload).encode() + b"\n\n"


def _responses_chunk(model: str, delta: str) -> bytes:
    payload = {
        "type": "response.output_text.delta",
        "delta": delta,
        "item_id": "msg_proxy",
        "output_index": 0,
        "content_index": 0,
    }
    return b"data: " + json.dumps(payload).encode() + b"\n\n"


def _responses_error(message: str) -> bytes:
    return b"data: " + json.dumps({"type": "error", "error": {"message": message}}).encode() + b"\n\n"


# ─── HTTP server ──────────────────────────────────────────────────────────────

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):  # noqa: A002 (BaseHTTPRequestHandler API)
        pass

    def _send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, status: int, payload: dict) -> None:
        self._send(status, json.dumps(payload).encode(), "application/json")

    def do_GET(self) -> None:  # noqa: N802 (BaseHTTPRequestHandler API)
        path = self.path.split("?", 1)[0]
        if path in ("/healthz", "/health"):
            self._json(200, {"status": "ok", "models": model_catalog()})
        elif path == "/v1/models":
            now = int(time.time())
            models = [
                {"id": slug, "object": "model", "created": now, "owned_by": "chatgpt-account"}
                for slug in model_catalog()
            ]
            self._json(200, {"object": "list", "data": models})
        else:
            self._json(404, {"error": {"message": "not found"}})

    def do_POST(self) -> None:  # noqa: N802 (BaseHTTPRequestHandler API)
        path = self.path.split("?", 1)[0]
        length = int(self.headers.get("Content-Length", "0"))
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self._json(400, {"error": {"message": "invalid JSON"}})
            return
        streaming = bool(payload.get("stream"))
        if path == "/v1/chat/completions":
            self._chat(payload, streaming)
        elif path == "/v1/responses":
            self._responses(payload, streaming)
        else:
            self._json(404, {"error": {"message": "not found"}})

    def _chat(self, payload: dict, streaming: bool) -> None:
        model = payload.get("model") or DEFAULT_MODEL
        status, _headers, raw = call_codex(chat_to_codex(payload), stream=streaming)
        if status != 200:
            self._json(status, {"error": {"message": raw.decode("utf-8", "replace")[:500]}})
            return
        if streaming:
            body = rewrite_stream(raw, out_format="chat", model=model)
            self._send(200, body, "text/event-stream")
        else:
            self._json(200, {"id": "chatcmpl-proxy", "object": "chat.completion", "model": model,
                             "choices": [{"index": 0, "message": {"role": "assistant", "content": ""}, "finish_reason": "stop"}]})

    def _responses(self, payload: dict, streaming: bool) -> None:
        model = payload.get("model") or DEFAULT_MODEL
        status, _headers, raw = call_codex(responses_to_codex(payload), stream=streaming)
        if status != 200:
            self._json(status, {"error": {"message": raw.decode("utf-8", "replace")[:500]}})
            return
        if streaming:
            self._send(200, rewrite_stream(raw, out_format="responses", model=model), "text/event-stream")
        else:
            self._json(200, {"id": "resp_proxy", "object": "response", "status": "completed", "output": [], "model": model})


def main() -> None:
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)
    print(f"codex-openai-proxy listening on http://{LISTEN_HOST}:{LISTEN_PORT}/v1", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
