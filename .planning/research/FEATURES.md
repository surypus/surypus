# Feature Research

**Domain:** Small-business ERP — accounting + inventory (Haskell implementation)
**Researched:** 2026-10-23
**Confidence:** HIGH for table stakes; MEDIUM for differentiators and repo-specific anti-features

## Scope Frame

The milestone is one working vertical path:

```
goods -> goods receipt -> sales invoice -> customer payment -> ledger entries -> stock balance
```

"Working" means: real PostgreSQL, one canonical write path, balanced double-entry postings, a
stock balance that reconciles to movements, and a server-rendered UI usable by the three roles.
Everything below is judged against that slice — **not** against a full ERP suite.

Two consequences shape the whole analysis:

1. **A receipt needs a supplier and an invoice needs a customer.** A counterparty mini-master is
   therefore table stakes even though the milestone text does not name it.
2. **The invoice must issue stock.** If invoice posting does not create an `ISSUE` movement and a
   COGS entry, the stock balance never decreases and the "end-to-end path" is only half real.

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = the slice is a demo, not an ERP.

#### Master Data

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Goods catalog | Every document line references a good; without it there is nothing to receive or sell | MEDIUM | Code/SKU, name, unit of measure, category, default VAT rate, sale price, active flag. List/search/detail. Keep one price field; price lists are an anti-feature. |
| Counterparty mini-master | A receipt names a supplier; an invoice names a customer | LOW | Name, type (`SUPPLIER`/`CUSTOMER`/`BOTH`), optional INN/KPP. No CRM fields, contacts, addresses, or credit terms in v1. |
| Single warehouse record | Stock must be keyed by location even if only one exists today | LOW | Seed one warehouse. Model `stock_balances(goods_id, warehouse_id)` so multi-warehouse is additive later, but expose no warehouse switcher. |
| Safe master-data lifecycle | Deleting a good or counterparty that has documents corrupts history | LOW | Deactivate (`is_active = false`) instead of delete; block hard delete when referenced. |
| Unit of measure | Quantities are meaningless without a unit | LOW | Free-text or a small seeded list (`pcs`, `kg`, `l`, `m`). A full UOM conversion engine is not v1. |

#### Stock

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Goods receipt document | The only legitimate way stock enters the system | MEDIUM | Header: number, date, supplier, warehouse, status. Lines: goods, quantity, unit cost. Posting increases stock and creates the AP entry. |
| Append-only stock movement ledger | Every quantity change must be explainable | MEDIUM | `RECEIPT`, `ISSUE`, `ADJUSTMENT`; each row carries source document type/id and timestamp. No update/delete. |
| Stock balance view | "How much do we have?" is the first question every user asks | LOW | Derive on-hand from movements (view or aggregate); a cached balance may exist only as a rebuildable projection, never as the sole truth. |
| Automatic issue on invoice posting | A sale that does not reduce stock is visibly wrong | MEDIUM | Invoice posting writes `ISSUE` lines and the COGS/Inventory journal pair in the same transaction. |
| Negative-stock block | Overselling silently is unacceptable in a real warehouse | LOW | Reject posting with a specific error: good, warehouse, requested, available. An override policy is v1.x. |
| Moving-average unit cost | COGS and stock valuation need a defensible cost | MEDIUM | Receipt updates the weighted average; invoice COGS = quantity × current average. FIFO/lots/serials are deliberately deferred. |
| Movement history per good | Users must be able to trace why the balance is what it is | LOW | Filter movements by good/warehouse/date; link to source document. |

#### Invoicing

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Sales invoice with lines | The central revenue document | MEDIUM | Header: number, date, customer, due date, status. Lines: goods, quantity, unit price, VAT rate, line net/VAT/gross. Totals: net, VAT, gross. |
| Unique human-readable numbering | Legal and operational requirement; duplicates destroy trust | MEDIUM | Per document type and year, monotonic. Generate inside the same DB transaction (sequence or `UPDATE ... RETURNING` counter); never `max(number)+1` in Haskell. |
| Draft → posted lifecycle | Users need to prepare documents before they affect the books | MEDIUM | Only drafts are editable. Posting is atomic: status, stock, and journal either all commit or none do. |
| Posted-document immutability | An accounting record that can be edited is not an accounting record | MEDIUM | No update/delete after posting. Corrections go through void/reversal, not editing. |
| VAT calculation contract | VAT is the tax the product exists to get right | LOW | One documented convention: rates stored as percent (`RatePercent`), VAT added on top of net by default, rounded half-up per line to 2 dp, document totals = sum of lines. Do not support both inclusive and exclusive in v1. |
| Invoice HTML view / print | Invoices get sent to customers | LOW | Server-rendered HTML with a print stylesheet. PDF generation is explicitly out of scope. |
| Void draft | Mistakes happen before posting | LOW | Void only `DRAFT`. Reversal of posted invoices/credit notes is v1.x. |

#### Payments

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Record payment against an invoice | Closing the receivables loop is the point of the slice | MEDIUM | Amount, date, method (cash/bank/card), reference. Partial payments allowed. |
| Payment ledger posting | Cash received must hit the books | MEDIUM | `Dr Cash / Cr Accounts Receivable`. Same atomic posting contract as invoices. |
| Invoice settlement status | Users need to see unpaid / partial / paid / overdue | LOW | Derive from posted payments and due date. Never store a status that can drift from the payments. |
| Overpayment rejection | Allocating more than the invoice balance creates negative AR | LOW | Reject with the remaining balance in the error. Customer advances/on-account payments are v1.x. |
| Payment direction (in/out) | A supplier exists because goods were received on credit | LOW (if posting templates exist) | The milestone needs inbound only, but the receipt leaves an AP balance. Adding `OUTBOUND` (`Dr AP / Cr Cash`) is one more template and makes the ledger honest. Recommended for v1. |

#### Ledger and Chart of Accounts

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Seeded flat chart of accounts | Every posting needs a destination account | LOW | ~10–15 accounts: cash, bank, AR, inventory, AP, VAT output, VAT input, revenue, COGS, retained earnings. Code, name, type (asset/liability/equity/revenue/expense), normal balance, active. Flat is enough; hierarchy is v1.x. |
| System-account role mapping | Posting rules must not hardcode account IDs | LOW | Named roles (`inventory`, `ar`, `ap`, `cash`, `vat_output`, `revenue`, `cogs`) map to account IDs in config/DB. This is the difference between a reseedable system and one that breaks when account IDs change. |
| Automatic posting rules per document type | Users should never hand-write journal entries for routine operations | HIGH | Three templates: receipt, invoice, payment. Posting rules are the core domain logic of the slice; budget accordingly. |
| Atomic balanced journal write | Σ debit = Σ credit is the product's core promise | HIGH | Enforce before commit; write immutable `ledger_entries`; link every line to its source document. A failed balance check must abort the whole document posting. |
| Ledger by account | The trial balance is not trustable if users cannot drill into it | MEDIUM | Date range, opening balance, running balance, debit/credit columns, source-document link. |
| Audit fields on postings | "Who posted this and when?" is a basic accounting control | LOW | `created_by`, `posted_by`, `posted_at` on documents; journal batch carries the same. |

#### Trial Balance

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Trial balance (turnover balance sheet) | The minimum proof that the books are coherent | MEDIUM | Per account: opening Dr/Cr, period Dr/Cr turnover, closing Dr/Cr; totals row. Date range; posted entries only. |
| Balance assertion surfaced | A trial balance that silently "balances" by rounding is worse than none | LOW | If total debits ≠ total credits, show the discrepancy as a hard error. Never apply a tolerance to hide it. |

#### Access, Roles, UI

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Local login/logout with server-side session | Every action must be attributable | MEDIUM | Opaque session ID in an `HttpOnly` cookie; session row in Postgres; per-user random salt + slow KDF (PBKDF2 via existing `cryptonite` is sufficient). Do not reuse the broken JWT login path. |
| Three fixed roles + permission matrix | The milestone names exactly three roles | MEDIUM | `admin`, `accountant`, `storekeeper`. Fixed matrix in code; no role editor. See matrix below. |
| Default-deny route authorization | Fail-open authorization is the existing codebase's worst security defect | MEDIUM | Every route maps to a permission; unmapped route = 403, not allow. Apply to HTMX fragment routes too, not just page routes. |
| Admin user management | Someone must create the accountant and storekeeper | MEDIUM | Create user, assign one role, deactivate. Password reset can be admin-set in v1. |
| Server-rendered UI shell | The milestone requires a usable UI, and the repo has no HTML layer yet | MEDIUM | Nav + list/detail/form patterns for goods, receipts, invoices, payments, ledger, trial balance, users. POST-redirect-GET, inline validation errors. HTMX for add/remove line and total recalculation. |
| Canonical seed + one-command smoke scenario | The slice must be reproducible on a fresh database | LOW | Seed users/roles, warehouse, counterparties, goods, chart of accounts, account-role map. A script posts the chain and asserts trial balance = 0 and stock balance = expected. Existing seeds are stale (see constraints). |

### Permission Matrix (v1, fixed)

| Capability | admin | accountant | storekeeper |
|------------|:-----:|:----------:|:-----------:|
| Goods: read | ✓ | ✓ | ✓ |
| Goods: create/update/deactivate | ✓ | — | — |
| Counterparties: read/write | ✓ | ✓ | — |
| Receipts: create/post | ✓ | — | ✓ |
| Stock balances/movements: read | ✓ | ✓ | ✓ |
| Stock adjustment | ✓ | — | — |
| Invoices: create/post/void | ✓ | ✓ | — |
| Payments: create/void | ✓ | ✓ | — |
| Ledger / trial balance / drill-down | ✓ | ✓ | — |
| Users & roles | ✓ | — | — |

Field-level hiding (e.g. cost price from storekeeper) is **not** v1; route-level enforcement is.

### Differentiators (Competitive Advantage)

For this product, differentiation is trust and operability, not module count.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Machine-checked ledger invariant | "The books cannot silently unbalance" is the strongest claim an accounting product can make | MEDIUM | LiquidHaskell refinement on the balance function plus QuickCheck properties on posting rules. Do not claim "verified" unless the check actually gates CI. |
| Exact decimal money + typed VAT units | No cent drift and no 100× rate bug at module boundaries | LOW–MEDIUM | `Data.Decimal` everywhere; `RatePercent` vs `RateFraction` newtypes; ban `Double` for money and rates. |
| Idempotent posting | A double-click or retry cannot double-post a document | LOW | Posting a posted document returns the existing result (or a typed conflict); unique constraint on `(document_type, document_id, posting_seq)`. |
| Full document → journal → stock traceability | Every reported number is drillable to its source document | LOW | Foreign keys plus UI links; no orphan journal lines. |
| Rebuildable stock balance | Stock can be recomputed from movements and audited | LOW | Balance is a view/projection; a rebuild command proves equality. |
| Typed posting templates | Adding a document type cannot accidentally bypass double entry | MEDIUM | Represent each template as a pure function `Document -> [JournalLine]` with a balance proof obligation. |
| Deterministic demo / smoke scenario | A reviewer can reproduce the entire chain in one command | LOW | This is a real adoption and QA advantage for a brownfield rescue project. |
| Russian statutory fit | Local codes, НДС 20%, RUB, ИНН/КПП are what the target user actually needs | LOW | Seed Russian account codes (41, 50, 51, 60, 62, 68.02, 90.01, 90.02) as data, not constants. Validate with the product owner; confidence MEDIUM. |
| Single binary, Postgres-only, HTMX UI | One person can operate it; no Redis, Kafka, or JS build chain | LOW | Operational simplicity is a genuine differentiator against Odoo/ERPNext for a small team. |

### Anti-Features (Commonly Requested, Often Problematic)

Deliberately **not** built in the first working version.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Event sourcing as the primary write model | The repo already has an event store, so it looks "free" | Two sources of truth, replay/versioning/projection complexity, and the relational ledger is still needed. Posting becomes eventually consistent — unacceptable for books | One DB transaction writes document + journal + stock movement. Keep the ledger append-only and immutable; derive balances with SQL |
| Background job queue for posting | Four queue implementations already exist | Async posting creates "document posted, no ledger yet" states and retry duplicates | Post synchronously inside the request transaction. Queues only for later exports/notifications |
| Multi-tenancy and tenant provisioning | Tenant columns and RLS already exist | Every query needs a tenant predicate; the current global `IORef` leaks tenants; provisioning is unfinished | Keep `tenant_id` columns with one seeded tenant. No tenant switcher, no onboarding, no RLS work in this milestone |
| Multi-currency / FX revaluation | "Real ERPs have it" | Rates, document vs functional currency, gain/loss accounts, revaluation runs; multiplies every total and report | One currency (RUB) seeded; reject other currency values. Add currency later behind an explicit migration |
| Multi-warehouse, transfers, bin locations | Warehouses are a visible ERP feature | UI, transfer documents, in-transit stock, per-warehouse costing | One seeded warehouse. Schema is warehouse-keyed so expansion is additive |
| FIFO / LIFO / lots / serials / expiry | Inventory sophistication signals "real ERP" | Costing layers, lot selection, expiry policy, returns handling; large correctness surface | Moving-average cost only. Unit cost captured on receipt |
| Manual journal entries | Accountants expect to "just post an adjustment" | Bypasses posting rules; easy to unbalance or misclassify; needs its own approval/permission model | Automatic postings only in v1. Admin-only adjustment document with a reason code in v1.x |
| Editing or deleting posted documents | Users want to "fix a typo" | Destroys auditability and can desynchronise stock, AR/AP, and ledger | Void drafts; posted corrections via reversal/credit note (v1.x). Posted rows are immutable |
| Full chart-of-accounts CRUD | Feels like configuration | Renaming/reparenting accounts with postings breaks report comparability; deletion orphans entries | Seed the chart; read-only in v1. Admin may add a leaf account in v1.x; codes immutable once used |
| Period close / lock dates / fiscal years | Standard accounting control | Adds close state to every query and posting, reopening workflows, and period-status UI | Date-range reports only. Validate document dates are not in the future; no close in v1 |
| Purchase orders + 3-way match + approvals | Procurement is the "proper" flow | PO → GRN → bill matching, tolerances, approval states; several documents before any stock moves | Direct goods receipt. PO/approval workflow deferred until the core path is stable |
| Credit notes, returns, debit notes | Real businesses return goods | Reverses stock, revenue, VAT, and COGS with different rules per case; needs its own document types | Void drafts; reversal document in v1.x when returns are actually required |
| Custom roles / permission editor | "We need a report-only auditor" | Role explosion, permission drift, UI for grants, testing matrix | Three fixed roles. Add a fourth role only with an explicit requirement |
| OAuth / LDAP / SSO / JWT for the UI | Enterprise expectation; JWT code exists | Refresh-token flow is broken, role claim is empty, secret handling is unsafe | Local users + server-side session cookie. External identity is out of scope |
| PDF / Excel export, dashboards, report builder | Users ask for "the report we had in Excel" | Rendering dependencies, templates, storage, retention; distracts from ledger correctness | Server-rendered HTML + browser print. CSV/PDF after the numbers are trusted |
| Public REST/GraphQL API in v1 | The repo already advertises one | Doubles every operation and test surface; existing API is largely stubs and fail-open | UI-first routes. Keep `/health`; add a read-only JSON surface later if a client needs it |
| Discounts, price lists, promotions | Sales teams expect them | Discount allocation across lines, VAT base changes, rounding rules, audit questions | One editable unit price per invoice line; no discount engine |
| Negative stock allowed / "warn only" | Convenience for busy warehouses | Makes COGS and stock valuation undefined; hides receiving errors | Hard block with an explicit error. Override is a later, audited action |
| Barcodes, labels, scanning, mobile/PWA | Warehouse users ask immediately | Hardware integration, label rendering, offline sync | Type-ahead search by code/name. Barcode later |
| Data import/export tooling | Migration from spreadsheets feels urgent | Mapping UI, validation, partial failure handling; large scope | Seed script + SQL for v1. Import is a separate milestone |

## Feature Dependencies

```
Money + VAT canon (Decimal, RatePercent)
        │
        ▼
Goods catalog ────────┐
Counterparty master ──┼──> Receipt lines / Invoice lines
Warehouse ────────────┘             │
                                    ▼
Chart of accounts ──> Account-role map ──> Posting rules (receipt, invoice, payment)
                                                │
                                                ▼
                                      Balanced journal entries
                                                │
                          ┌─────────────────────┴─────────────────────┐
                          ▼                                           ▼
                    Trial balance                            Ledger drill-down
                          ▲
                          │
Stock movement ledger ──> Stock balance view ──> Invoice stock issue / COGS

Auth + session ──> RBAC matrix ──> every mutating route
Auth + session ──> created_by / posted_by audit fields
Document numbering ──> Receipt / Invoice / Payment creation
```

### Dependency Notes

- **Posting rules require the chart of accounts + account-role mapping.** Without the role map,
  every template hardcodes account IDs and breaks on reseed or account rename.
- **Invoice requires goods, counterparty, VAT canon, and stock.** Posting an invoice must issue
  stock and book COGS; therefore receipt must exist before the first invoice when negative stock
  is blocked.
- **Payment requires a posted invoice** for allocation. Partial payment requires the invoice
  balance to be derived from posted payments, not from a mutable `paid_amount` field.
- **Trial balance requires only posted journal entries.** It must not read document totals;
  otherwise there are two truths and they will diverge.
- **Stock balance requires the movement ledger.** A balance table may exist only as a
  rebuildable projection.
- **RBAC requires auth; audit requires auth.** Build session + user identity before document
  routes, or audit fields will be bolted on later and left null.
- **Document numbering requires a DB-side counter.** `max(number)+1` in application code races
  under concurrency and produces duplicates.
- **UI depends on all of the above.** Build it as a vertical slice per document (goods page →
  receipt page → invoice page → payment page → ledger/trial balance), not as a final phase.

### Conflicts

- **Event-sourced write model conflicts with atomic posting.** Choose the transactional write
  path for v1.
- **Editable posted documents conflict with immutable ledger and audit.** Choose immutability.
- **Multi-currency conflicts with the single money/VAT canon.** Choose one currency.
- **Manual journals conflict with automatic posting rules.** Choose automatic postings.
- **A mutable `paid_amount`/`stock.quantity` as truth conflicts with derived balances.** Choose
  derivations plus projections.

## MVP Definition

### Launch With (v1)

- [ ] Goods catalog with code, name, unit, category, VAT rate, sale price, active flag — every
      document line depends on it
- [ ] Counterparty mini-master (supplier/customer) — receipts and invoices need a party
- [ ] One seeded warehouse — stock must be location-keyed from day one
- [ ] Goods receipt with lines and posting — stock in, AP recognised
- [ ] Append-only stock movement ledger + derived stock balance — the "остаток" half of the goal
- [ ] Sales invoice with lines, VAT, numbering, draft/post, immutability — the revenue document
- [ ] Automatic stock issue + COGS on invoice posting — makes the balance respond to sales
- [ ] Payment against invoice, partial allowed — closes the receivables loop
- [ ] Seeded flat chart of accounts + account-role mapping — posting destinations
- [ ] Automatic posting rules for receipt/invoice/payment — the core of double entry
- [ ] Atomic balanced journal write with source-document links — the invariant
- [ ] Ledger by account + trial balance with opening/turnover/closing — proof the books work
- [ ] Login/logout with server-side session, three fixed roles, default-deny authorization
- [ ] Admin user management — someone must create the other two roles
- [ ] Server-rendered UI for the whole chain + canonical seed and smoke scenario

### Add After Validation (v1.x)

- [ ] Void/reversal for posted documents — when a real user posts a wrong invoice
- [ ] Credit notes / sales returns — when returns actually occur
- [ ] Manual stock adjustment document — when physical counts begin
- [ ] Outbound supplier payments — when AP must be settled (may be v1 if one template is cheap)
- [ ] Opening balances — when migrating from a spreadsheet or another system
- [ ] Account creation (leaf only) and archive — when the seeded chart is insufficient
- [ ] Audit-log viewer — when more than one person uses the system
- [ ] CSV export of trial balance/ledger — when the accountant asks for it
- [ ] Role-specific landing pages — when storekeeper/accountant workflows diverge in practice

### Future Consideration (v2+)

- [ ] Multi-warehouse and transfers — only with a second physical location
- [ ] FIFO/lots/serials/expiry — only when costing accuracy or traceability demands it
- [ ] Multi-currency and FX — only with foreign counterparties
- [ ] Purchase orders and 3-way match — only when procurement needs approval
- [ ] Period close and lock dates — only when the business closes books formally
- [ ] Bank reconciliation / statement import — only when bank volume justifies it
- [ ] Custom roles and field-level permissions — only with a concrete segregation-of-duties need
- [ ] PDF/Excel reports, dashboards, public API — after the ledger is trusted

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Goods catalog | HIGH | MEDIUM | P1 |
| Counterparty mini-master | HIGH | LOW | P1 |
| Warehouse + stock movement ledger | HIGH | MEDIUM | P1 |
| Goods receipt + posting | HIGH | MEDIUM | P1 |
| Stock balance view | HIGH | LOW | P1 |
| Sales invoice + VAT + numbering | HIGH | MEDIUM | P1 |
| Automatic stock issue/COGS | HIGH | MEDIUM | P1 |
| Payment against invoice | HIGH | MEDIUM | P1 |
| Chart of accounts + role map | HIGH | LOW | P1 |
| Posting rules + balanced journal | HIGH | HIGH | P1 |
| Ledger by account | HIGH | MEDIUM | P1 |
| Trial balance | HIGH | MEDIUM | P1 |
| Login/session + 3 roles + default-deny | HIGH | MEDIUM | P1 |
| Server-rendered UI shell | HIGH | MEDIUM | P1 |
| Canonical seed + smoke scenario | MEDIUM | LOW | P1 |
| Void draft | MEDIUM | LOW | P2 |
| Outbound supplier payment | MEDIUM | LOW | P2 |
| Posted-document reversal | HIGH | MEDIUM | P2 |
| Credit notes / returns | MEDIUM | HIGH | P2 |
| Opening balances | MEDIUM | MEDIUM | P2 |
| Account creation/archive | LOW | LOW | P3 |
| CSV export | MEDIUM | LOW | P3 |
| Multi-warehouse / FIFO / multi-currency / PO / period close | MEDIUM | HIGH | P3 (defer) |

## Existing-Code Constraints (Do Not Build On These)

These directly affect feature scope; they are not generic pitfalls.

- **`Surypus.API.Goods` is a stub** (`listGoods` returns `[]`, `getGood` returns "Not found").
  Do not count it as an existing goods feature.
- **`DAL.DB` is an in-memory fixture** still imported by `Service/BillService.hs`. Do not build
  receipt/invoice/payment features on it; remove the import.
- **`DAL.Repository.RBAC.checkUserAppPermissionRepo` always returns `True`.** Do not reuse it;
  build the permission check on the chosen canonical role tables.
- **The JWT login path is broken** (register stores a hash, login compares raw password;
  refresh returns an empty token). Do not extend it for the UI. Use a server-side session.
- **`Surypus.DB.Schema` uses singular table names** (`payment`, `user`, `stock`,
  `stock_movement`, `acc_plan`) that do not match the migrations (`payments`, `users`,
  `stock_balances`, `stock_movements`, `chart_of_accounts`). Pick the migration schema.
- **Two competing schemas exist.** `V001__core_schema.sql` creates `accounts`, `journal_entries`,
  `bills` (no `tenant_id`), and `payments`; `V256__domain_organization_final.sql` creates
  `chart_of_accounts`, `ledger_entries`, `bills` (tenant-scoped), `bill_lines`, `goods`, and
  `stock_balances`. Because both use `CREATE TABLE IF NOT EXISTS`, the effective `bills` shape
  depends on migration order and duplicate `V001` files. **The invoice/receipt feature is blocked
  until a forward migration settles this and acceptance runs on a fresh database.**
- **The seeds are stale.** `sql/seeds/demo_seed.sql` inserts into `goods(id, price, company_id)`,
  `stock(quantity, reserved_quantity)`, and `bills(company_id)`, none of which exist in the V256
  shape. Write a new canonical seed; do not patch the old one.
- **No HTML or cookie library is in `Surypus.cabal`.** A server-rendered UI needs one HTML DSL
  (e.g. `lucid`/`blaze-html`) and cookie/session handling. This is a real dependency to plan,
  not scope creep.
- **There are already three `Stock` types and multiple ledger modules.** Build exactly one
  persisted stock type and one ledger path; do not add another.

## Competitor Feature Analysis

| Feature | Odoo / ERPNext | 1C:Бухгалтерия / 1C:ERP | QuickBooks / Xero | Small ERPs (SimpleERP, Celerp) | Our Approach |
|---------|----------------|--------------------------|-------------------|-------------------------------|--------------|
| Goods catalog | Rich: variants, attributes, price lists, barcodes | Rich: nomenclature, characteristics, units, price types | Product/service with SKU, price, tax | SKU, category, price, tax | Six fields + active flag; no variants/price lists |
| Stock | Multi-warehouse, lots/serials, FIFO/AVCO, transfers | Warehouses, batches, serials, transfers | Basic stock (QuickBooks) or none (Xero) | Multi-warehouse, FIFO/expiry in higher tiers | One warehouse, movement ledger, moving average |
| Invoicing | Sales orders → invoices, taxes, multi-currency | Invoices, acts, VAT, multi-currency | Invoices, recurring, multi-currency | Invoices with lines/tax/partial payment | One sales invoice type, per-line VAT, partial payment |
| Payments | Reconciliation, partial, multi-currency | Bank/cash documents, allocations | Bank feeds, reconciliation | Receipts applied to invoices | Manual payment against one invoice; no bank feed |
| Ledger | Full double-entry, auto-postings, journals | Full double-entry, statutory chart | Full double-entry behind the UI | Auto-posted double entry | Automatic postings only, immutable, balanced |
| Chart of accounts | Configurable, hierarchical | Statutory Russian chart | Configurable | Seeded simple chart | Seeded flat chart + system-role map |
| Trial balance | Built-in + P&L/balance sheet | Oборотно-сальдовая ведомость + statutory reports | Reports | Trial balance + P&L | Trial balance with opening/turnover/closing; no P&L v1 |
| Roles | Granular, record rules | Granular, statutory roles | Basic user/accountant | Per-module roles | Three fixed roles, route-level |
| Positioning | Broad suite, heavy configuration | Statutory compliance, complex | SaaS, bank-centric | Module bundles | One verified vertical path, self-hosted, minimal ops |

## Confidence Notes

| Area | Confidence | Reason |
|------|------------|--------|
| Table stakes | HIGH | Standard accounting/inventory practice, corroborated by multiple current vendor feature pages and by the repo's own V256 schema |
| Differentiators | MEDIUM | Product-positioning judgement; the technical claims are feasible but value depends on the target user |
| Anti-features | HIGH (domain) / MEDIUM (repo-specific) | Scope-creep patterns are well documented; repo-specific constraints are verified in source |
| Russian statutory fit | MEDIUM | Inferred from НДС/ИНН/КПП and Russian docs; needs product-owner confirmation before committing account codes |

## Sources

- Repo: `.planning/PROJECT.md`, `.planning/codebase/CONCERNS.md`, `.planning/codebase/ARCHITECTURE.md`
- Repo: `sql/migrations/V001__core_schema.sql`, `sql/migrations/V256__domain_organization_final.sql`,
  `sql/migrations/V006__roles.sql`, `sql/migrations/V009__rbac_store.sql`, `sql/seeds/demo_seed.sql`
- Repo: `src/DAL/Types.hs`, `src/DAL/Schema.hs`, `src/Surypus/DB/Schema.hs`,
  `src/Finance/Types.hs`, `src/Finance/Account.hs`, `src/Surypus/API/Goods.hs`,
  `src/Surypus/API/Payment.hs`, `src/Surypus/API/Server.hs`
- [SimpleERP features](https://simpleerpsoftware.com/features) — module boundaries for small business (MEDIUM)
- [ineed.now ERP](https://www.ineed.now/erp/) — requisition→ledger chain; trial balance from postings (MEDIUM)
- [Really Simple ERP features](https://reallysimpleerp.com/features/) — double-entry, seeded chart, partial payments (MEDIUM)
- [Celerp inventory/ERP](https://celerp.com/) — stock costing tiers, local-first positioning (MEDIUM)
- [SaleSprint feature catalog](https://salesprint.org/features/all) — feature-tier separation of costing/warehouse/multi-currency (MEDIUM)
- [Scoping an MVP that ships](https://www.ervandra.com/blog/scoping-an-mvp-that-ships) — one workflow end to end, visible "not now" list (MEDIUM)
- [ERP scope management](https://www.erpimplementation.eu/en/erp-functional-scope-5-methods-prevent-scope-creep/) — MoSCoW, explicit "won't have", phased delivery (MEDIUM)
- [Zelvori V1 scope guardrails](https://zelvori.software/solutions/business-operations/) — explicit exclusions (multi-currency, speculative forecasting) (MEDIUM)

---

*Feature research for: small-business ERP accounting + inventory slice*
*Researched: 2026-10-23*
