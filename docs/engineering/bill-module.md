# Module 01 — Document / Bill Core

*Chosen as the first real porting target because `Src/PPLib/BILL.CPP` is the central actor in document management, and Surypus already has a partial Bill/Invoice domain (API, DTOs, schema, invariants) that can be formalized and extended.*

## 1. Анализ исходной реализации
- `BillCore` encapsulates searches (`SearchByID`), memo storage (`PutItemMemo`/`GetItemMemo`), amount tables (`BillAmountTbl`) and EDI flags (`BillTbl::Rec`).
- Documents coordinate: EDI/Flags → amount lookups → posting/stock movements → status updates (posted, archived, canceled).
- File references such as `CheckAmtTypeRef`, `GetAmountList`, `CalcBillLineAmount` define invariants that Surypus must encode with LiquidHaskell.
 - Документ `bill.cpp` также содержит методы `BillCore::GetAmount`, `GetAmountList`, `GetQttyEpsilon`, `SetRecadvStatus`/`SetRecadvConfStatus` — эти методы задают инварианты остатков, документов и статусов, которые нужно отразить в LiquidHaskell.
 - При публикации документа `BillCore::Post` (далее в файле) вызывает `CalcBillLineAmount`, `GetAmountList`, `CheckAmtTypeRef`, `GetQttyEpsilon` и затем направляет накопленные суммы в `AccTurn`/`Stock` — Surypus должен сохранить эту последовательность через Hasql + SQL-процедуры.

## 1.1 Потоки данных и управления
1. Пользователь создаёт или обновляет `BillTbl::Rec`, заполняя `Flags2` (EDI, статус) и строки (`BillLineTbl`). `BillCore::BillCore`/`BillCore::UpdateStatus` проверяют и модифицируют флаги перед сохранением.
2. `BillCore::GetAmountList` и `AmtEntry` строят список сумм по типам (`AmtTypeID`), который затем используется `BillCore::CheckAmtTypeRef`/`BillCore::SelectAmountType` при постинге: суммы должны совпадать с сформированными проводками.
3. При постинге `BillCore::Post`:
   - вычисляет `lineAmount` через `CalcBillLineAmount` (чистая логика: qty*price – discount + tax),
   - вызывает `MakeOrder`, `AccTurn`, `Stock`/`Lot` для отражения движения товаров и бухгалтерии,
   - обновляет `BillTbl::Flags2` (статусы: `BILLF2_POSTED`, `BILLF2_EDI_*`).
4. `BillCore::SetRecadvStatus`, `SetRecadvConfStatus` устанавливают флаги EDI-статусов (принят/отклонён/промежуточный). Surypus должен иметь типы `BillEdiStatus`/`BillEdiConfStatus` с теми же значениями и функции, поддерживающие `Flags2` в `BillLine`.
5. `BillCore::GetQttyEpsilon` возвращает значение точности для проверок остатков; Surypus должен хранить это значение в конфиге и использовать в LiquidHaskell-выражениях (например, `qtty_eps` при сопоставлении остатков лотов).

## 1.2 Ключевые инварианты (формальные предпосылки)
- Вся сумма строк должна равняться счету: `Σ calcBillLineAmount line == billAmount`, `Σ calcLineTaxExpected line == billVat`, `billAmount ≥ 0`, `billVat ≥ 0`, `billDiscount ≥ 0`.
- `BillLine`: `quantity ≥ 0`, `price ≥ 0`, `discount ≥ 0`, `tax ≥ 0`, `amount == clampNonNeg (quantity×price - discount + tax)`. Эта логика повторяется в `CalcBillLineAmount` и `BillLineTbl`.
- Для постинга: `Σ debit = Σ credit`, `Σ lot.qty` неотрицательны, `lot.qty_out` ≤ `lot.qty`, `lot.posted` устанавливается только после `Accounting`/`Stock`.
- EDI-флаги `Flags2` изменяются только через `SetRecadvStatus/SetRecadvConfStatus` с фиксированными масками `BILLF2_EDI_*`; в Surypus нужно отражать эти флаги в типе `BillEdiFlags` и через функции, подобные `documentRegisterTypeHasFlag`.
- `GetAmountList` и `AmtType` гарантируют, что каждая сумма привязана к `curID` и `amtTypeID`. Схема `bill_amount` должна иметь уникальный `(bill_id, amt_type_id, cur_id)` и Linked `core.amount_type` — стоит ввести это в SQL и втерминальном Hasql-модуле.
- Вставка строки/постинг должна быть атомарной: Surypus должен использовать транзакции Hasql и хранить контрольные суммы (например, хеш `sum(amount)`), чтобы LiquidHaskell можно было проверить свойства перед коммитом.

## 1.3 Как использовать в Surypus
- `Core.Document.Types` уже определяет `DocumentRegister`, `DocumentOpCounter` и функции проверок; нужно создать `Core.Bill.Flags`, `Core.Bill.Edi` с LiquidHaskell-предикатами `isBillPosted`, `billVatValid`.
- `DB.Bill` должен содержать Hasql-запросы, повторяющие логику `BillCore` (insert/update/status change) и использовать новые схемы `bill_amount`, `bill_line`, `bill_flags` с проверками уникальности (ссылки на `schema_Core_Document_*`).
- Расширить `Domain.Bill` на `BillEdiStatus`, `BillPostStatus`, `BillLineStatus` и `BillFlags` с проверками, основанными на `BillCore`.
- Написать property-based тесты (QuickCheck) на `calcBillTotal` и `calcLineTaxExpected`, рассматривая `GetQttyEpsilon`, `Clamp` — сопоставить с SQL-агрегациями (`calc_bill_totals` в `procedures.sql`).
## 2. Surypus current state
- Existing REST API covers `/api/v1/bills` with CRUD, but posting is a stub and JWT/authn is only placeholder.
- `Domain.Bill` already declares refinement types (`NonNegDouble`) and `calcBillTotal`, yet the invariants from BillCore (EDI flag consistency, every amount record, balanced debit/credit) are not enforced end-to-end.
- PostgreSQL schema has `bill`, `bill_line`, `stock`, and procedures in `sql/procedures.sql`, but they need to mirror BillCore flows (amount tables, statuses, stock ALE). `schema_bill.sql` exists, but there is no dedicated schema per `Core.Document` vs `Core.Accounting` causing name collisions (e.g., `acc_sheet`).

## 3. Unique schema/module plan
- **Schema isolation.** Each object (AccSheet, Register, OpCounter, RegisterType, etc.) now has a dedicated SQL schema file and table (`document_register`, `document_register_type`, `ppobj_register`, `document_op_counter`, `common_op_counter`, `acc_sheet_accounting`, `acc_sheet_finance`, etc.), ensuring the Finance/Accounting kernels cannot collide with the Document/Legal registries. Initialization scripts were re-ordered so that type tables are created before they are referenced by dependent views/triggers.
- **LiquidHaskell foundation.** `Core.Document.Types` declares `DocumentRegister`, `DocumentRegisterType`, `DocumentOpCounter` with refinements (non-empty numbers, bounded flags, prefix length constraints) and helper validators (`validateDocumentRegister`, `validateDocumentOpCounter`) that the Domain layer can reuse when ingesting API payloads.
- **Repository boundaries.** Unique Hasql modules will eventually wrap the new tables (e.g., `DB.Document.Register`, `DB.Document.Counter`) so that the document-side logic is isolated from the shared `bill`, `stock`, and `accounting` infrastructure.

## 4. Data flows to encode
1. API request → Domain `Bill` → `calcBillLineAmount` / `validateBill` (LiquidHaskell invariants: amounts ≥ 0, totals match, statuses valid).\
2. Domain → Hasql `DB.Bill` (insert/update) → stored procedures `calc_bill_totals`, `post_bill`, `apply_bill_movements`.\
3. On bill posting: enforce `Σ debit = Σ credit`, update `stock`/`lot` (refer to `BillCore::GetAmountList`, `BillCore::CheckAmtTypeRef`).\
4. Mirror EDI states via `Flags2` in SQL (fields `edi_status`, `edi_conf_status`), with helpers to set status using pure functions that match BillCore flags.

## 5. Liquidhaskell invariants to add
- `BillLine` type refinements should include `taxRate` boundaries, `qtty >= 0`, `price >= 0`, `amount == clampNonNeg qtty*price - discount + tax`, and `billStatus` must be within known operation kinds.
- `Bill` body invariants: `billAmount >= 0`, `billVat >= 0`, `billDiscount >= 0`, `billLines` non-empty for posted documents, `billLines` total equals `billAmount`, `Σ lines tax = billVat`, `flags` correspond to statuses (e.g., posted/canceled). LiquidHaskell predicates should reference new `Core.Document.Types` for statuses.
- Define `{-@ type PositiveAmt = {v:Double | v >= 0 && v <= 1e12} @-}` for amounts stored in DB to control numeric ranges.

## 6. Stored procedures & Hasql plan
- Extend `sql/procedures.sql` with: `create_bill_line`, `apply_bill_posting` (debits/credits), `set_bill_edi_status`, `calc_bill_totals`, `update_bill_status`. Keep each procedure idempotent and express invariants via assertions.
- Add Hasql statements to `DB.Bill` for: `insertBillLine`, `postBill`, `setEdiStatus`, `fetchBillTotals`, `syncStock`. Ensure statements refer to schema names defined above to avoid collisions.

## 7. API + JWT + middleware
- Replace stub `/auth/login` token with real JWT signing using `jose`/`jwt` (secret stored in env). Return roles/policy.\
- Introduce middleware for logging, panic handling and authorization check (e.g., `requireRole`).\
- Expand `/api/v1/bills` routes with `POST /post` (idempotent), `PATCH /edi-status`, `PUT /lines`, verifying invariants before database.\
- Connect Document API to new `Core.Document` modules: use typed statuses and `OperationKind` type families for parametric operations.

## 8. Frontend/Reports/CI/tests
- QML frontend: new section for Documents, binding to `/api/v1/bills`. Provide forms for posting and EDI statuses with `BillLine` tables.\
- Reports: port Crystal/sales report to Jasper template `reports/bills_general.jrxml` and call via `Reports.generate`.\
- CI: add GitHub Actions to `Surypus/.github/workflows` (build/test/lint). Unit tests for `Domain.Bill` and integration tests hitting `/api/v1/bills`.\
- Add property-based QuickCheck verifying `calcBillTotal` equals DB aggregation when lines inserted.

## 9. Next immediate steps
1. Formalize `Core.Document.Types`/`Core.Document.Register` to reflect C++ invariants, create LiquidHaskell refinements. 
2. Expand `DB.Bill` with new statements, ensuring unique schema file for each register. 
3. Implement real JWT auth + middleware and extend API routes for posting/EDI handling. 
4. Keep iterating on schema/per procedure to encode the original logic (HR/Payroll, Production, Hardware will follow after Document core is stable).
