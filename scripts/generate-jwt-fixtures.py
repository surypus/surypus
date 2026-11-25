#!/usr/bin/env python3
"""Generate deterministic HS256 JWT fixtures used by JWTSpec/TenantIsolationSpec."""
import base64, hashlib, hmac, json
from pathlib import Path

SECRET = b"test-secret-key-that-is-long-enough-for-hs256"
API_BASE = {"sub": "42", "name": "test", "aud": "surypus-api",
            "iss": "surypus-api", "iat": 1735689600, "exp": 4102444800}
TENANT_BASE = {**API_BASE, "role": "user", "tenant_id": 7}

def b64(obj):
    return base64.urlsafe_b64encode(
        json.dumps(obj, separators=(",", ":")).encode()).rstrip(b"=").decode()

def jwt(payload, key=SECRET):
    h, p = b64({"alg": "HS256", "typ": "JWT"}), b64(payload)
    sig = base64.urlsafe_b64encode(
        hmac.new(key, f"{h}.{p}".encode(), hashlib.sha256).digest()).rstrip(b"=").decode()
    return f"{h}.{p}.{sig}"

def main():
    api = {
        "validToken": jwt(API_BASE),
        "expiredToken": jwt({**API_BASE, "exp": 1600003600}),
        "wrongAudienceToken": jwt({**API_BASE, "aud": "other-api"}),
        "noSubToken": jwt({k: v for k, v in API_BASE.items() if k != "sub"}),
        "wrongSecretToken": jwt(API_BASE, key=b"other-secret-key-that-is-also-long-enough"),
        "wrongIssuerToken": jwt({**API_BASE, "iss": "evil-issuer"}),
    }
    api["tamperedToken"] = api["validToken"][:-3] + "abc"
    tenant = {
        "tenantToken": jwt(TENANT_BASE),
        "noTenantToken": jwt({k: v for k, v in TENANT_BASE.items() if k != "tenant_id"}),
        "expiredToken": jwt({**TENANT_BASE, "exp": 1600003600, "iat": 1600000000}),
        "wrongAudToken": jwt({**TENANT_BASE, "aud": "other-api"}),
        "noSubToken": jwt({k: v for k, v in TENANT_BASE.items() if k != "sub"}),
        "wrongIssToken": jwt({**TENANT_BASE, "iss": "evil-issuer"}),
    }
    tenant["tamperedToken"] = tenant["tenantToken"][:-3] + "abc"
    out = Path(__file__).resolve().parents[1] / "test" / "fixtures" / "jwt-fixtures.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({**api, **tenant}, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {out}")

if __name__ == "__main__":
    main()
