#!/usr/bin/env python3
"""Generate deterministic HS256 JWT fixtures used by TenantIsolationSpec.hs."""
import base64, hashlib, hmac, json
from pathlib import Path

SECRET = b"test-secret-key-that-is-long-enough-for-hs256"
BASE = {"sub": "42", "name": "test-user", "role": "user",
        "aud": "surypus-api", "iat": 1735689600, "exp": 4102444800}

def b64(obj):
    return base64.urlsafe_b64encode(
        json.dumps(obj, separators=(",", ":")).encode()).rstrip(b"=").decode()

def jwt(payload, key=SECRET):
    h, p = b64({"alg": "HS256", "typ": "JWT"}), b64(payload)
    sig = base64.urlsafe_b64encode(
        hmac.new(key, f"{h}.{p}".encode(), hashlib.sha256).digest()).rstrip(b"=").decode()
    return f"{h}.{p}.{sig}"

def main():
    fixtures = {
        "tenant": jwt({**BASE, "tenant_id": 7}),
        "notenant": jwt(BASE),
        "expired": jwt({**BASE, "tenant_id": 7, "iat": 1600000000, "exp": 1600003600}),
        "wrongaud": jwt({**BASE, "aud": "other-api", "tenant_id": 7}),
        "nosub": jwt({k: v for k, v in BASE.items() if k != "sub"} | {"tenant_id": 7}),
    }
    fixtures["tampered"] = fixtures["tenant"][:-3] + "abc"
    api_base = {"sub": "42", "name": "test", "aud": "surypus-api",
                "iat": 1735689600, "exp": 4102444800}
    api = {
        "validToken": jwt(api_base),
        "expiredToken": jwt({**api_base, "exp": 1600003600}),
        "wrongAudienceToken": jwt({**api_base, "aud": "other-api"}),
        "noSubToken": jwt({k: v for k, v in api_base.items() if k != "sub"}),
        "wrongSecretToken": jwt(api_base, key=b"other-secret-key-that-is-also-long-enough"),
    }
    api["tamperedToken"] = api["validToken"][:-3] + "abc"
    fixtures.update(api)
    out = Path(__file__).resolve().parents[1] / "test" / "fixtures" / "jwt-fixtures.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(fixtures, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {out}")

if __name__ == "__main__":
    main()
