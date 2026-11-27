# Security audit — 2026-11-27

## S-01 (P0, FIXED) — fail-open authorization middleware

`Surypus.API.AuthMiddleware.withAuthzResolverAdvanced` previously did:

```haskell
Nothing -> app request respond          -- unmapped route: allowed
Just perm -> ... if hasPerm || checkPermission userRoles perm ...
```

An authenticated request to any route absent from the hardcoded permission
map was passed through, and JWT-declared roles could override a denying
permission store. Public paths were matched with a raw `T.isPrefixOf`, so
`/api/v1/auth` also opened `/api/v1/authors`.

Fixed in this task:

- Decision logic extracted to pure `Surypus.API.AuthorizationDecision`;
  unmapped routes now return **403** (`AuthForbidden`) — fail closed.
- The injected `checkPerm` store is the only authority; the JWT-role fallback
  was removed.
- Public paths match on segment boundaries (exact, trailing-`/` directory, or
  `path <> "/"`), so sibling prefixes stay protected.
- Bearer scheme is case-insensitive per RFC 6750; error JSON is escaped.
- Token verification is injectable (`withAuthzResolverWith`) for tests.

Verification: 8 WAI regression examples + 8 pure decision examples, all
passing; full suite 1234 examples / 0 failures.

Existing `RBACCanonSpec` test "denies an unmapped path by default" asserted
only that the *mapping function* returns `Nothing` — the old middleware then
allowed that request. The new WAI test asserts the actual HTTP status, closing
that false-confidence gap.

## Open findings

| ID | Severity | Finding | Status |
|---|---|---|---|
| S-02 | P0 | `app/Main.hs` does not use `apiServer`; deployed HTTP surface is a stub | OPEN |
| S-03 | P1 | `DAL.Queue.processJob` reports success without doing work | OPEN (module unreferenced by executable) |
| S-04 | P1 | `System.Secrets.storeSecret` stores plaintext under an "encrypted store" name | OPEN |
| S-05 | P2 | `EventProcessor.generateEventId` returns a constant, breaking idempotency/dedup | OPEN |
| S-06 | P2 | `EmailSender.sendEmail` simulates delivery and reports success | OPEN |
| S-07 | — | Tenant RLS enforced by `scripts/check-tenant-rls.sh`; script not executed here (needs PostgreSQL) | UNVERIFIED |

`generateToken` writes `role: []` into the JWT while `verifyToken` expects a
string; consequently `ucRoles` is empty for real tokens. The removed fallback
was therefore latent in production but still a bypass if a token ever carried
a role claim.
