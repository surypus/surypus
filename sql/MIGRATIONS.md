# Migration corpus — authoritative order

`scripts/migration-files.sh` is the single source of truth for migration order.
It emits paths in this fixed sequence:

1. `sql/migrations` (group 0)
2. `sql/event` (group 1)
3. `sql/projection` (group 2)
4. `sql/aggregate` (group 3)

Within a group: numeric `V<version>` prefix, then group, then full path.
Sorting uses `LC_ALL=C` — locale-dependent collation previously placed
`V001b__tenant_scoping.sql` before `V001__core_schema.sql`, and the chain failed
with `relation "bills" does not exist`.

Consumers of the list:

- `scripts/migrate.sh` — applies with checksum ledger and advisory lock.
- `scripts/ci-dry-run-mig.sh` — loads the same list in a rolled-back transaction.
- `scripts/ci-migration-verification.sh` — preflight plus the real load above.

## Deliberately excluded

- `sql/core/V001__rbac_schema.sql` — legacy RBAC schema variant. It uses
  `roles.role_name` while the canonical `sql/migrations/V001__core_schema.sql`
  defines `roles.name`; loading both fails. Kept as historical material.
- `sql/policy`, `sql/service` — not part of the applied chain.
- `sql/archive`, `sql/test`, `sql/seeds` — fixtures and historical files.
- `sql/procedures.sql` — loaded last by `ci-dry-run-mig.sh` only (canonical
  section through `post_bill`), per `DAL.Procedures` requirements.
- `sql/migrations/V*.generated.sql` — no such files exist; the old CI script
  referenced this pattern and therefore verified nothing.

## Verification

```bash
bash scripts/migration-files.sh | wc -l          # 374
bash scripts/migrate.sh --check-only             # preflight
TEST_PG_CONN=... bash scripts/ci-dry-run-mig.sh  # real load, rolled back
```
