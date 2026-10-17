# Module 03 — Production / Hardware

После стабилизации Document и HR/Payroll следующий критический блок — производство и связанный Hardware (MRP, техкарты, нормативы, job-сервер). Общий сценарий описан в `tech.cpp`, `ppbuild.cpp`, `ppordr.cpp` и смежных файлах: технологическая карта (`PPObjTech`), ресурсоёмкие заказы (`PPObjWorkOrder`), перемещения между складами и связка с `BillCore`/`AccTurn`.

## 1. Что делает исходная реализация (фокус на `tech.cpp`)
- `PPObjTech` хранит технологические структуры (`TechTbl`), которые связывают процессор (документ `Processor`) с товарами, формулами и типами операций (`TECK_AUTO`, `TECK_MANUAL`).
- `TechLines` (`TGSArray`) управляют списком `GoodsID` с коэффициентами (`Sign`) и формулами; реализованы методы `GetGoodsList`, `AddItem`, `SearchGoods_`, `CreateAutoTech`. Это позволяет из MRP автоматически подставлять компоненты и найти техкарту по сырью.
- `PPObjTech::GenerateCode` увеличивает глобальный счетчик `TecCounter` в `PPObjProcessor` и генерирует уникальные коды (с префиксом `TLNG` для tooling). Surypus должен сохранить этот счётчик в одной из таблиц (например, `tech_counter`) и гарантировать атомарность через транзакции.
- `PPObjTech::SearchAuto` и `SearchAutoForGoodsCreation` ищут автоматические техкарты по принадлежности товара к группе (`GoodsObj::BelongToGroup`). Производственные документы полагаются на эти поиски для определения компонентов, и они должны быть пока `Hasql` строит профили.

## 2. Где Surypus должен усиливать архитектуру
1. **SQL-схемы**: создать `schema_tech.sql`, `schema_work_order.sql`, `schema_mrp.sql`. Таблицы:
   - `tech_card` (id, processor_id, goods_group_id, kind, formula, flags, code);
   - `tech_line` (tech_id, line_no, goods_id, qty, sign, formula_text);
   - `work_order` (id, code, goods_id, qty_plan, qty_released, status, scheduled_at, start_at, end_at, processor_id);
   - `work_order_line` и `work_order_movement` (статики для склада, запасов).
   Добавить индексы на `processor_id`, `code`, `status`, `goods_id`. Уникальность: `(processor_id, goods_id, kind, code)` и `(work_order.code)`. Constraints:
   - `qty_plan >= 0`, `qty_released >= 0`, `status ∈ {0..4}` (например, pending/running/completed/cancelled/failed);
   - `tech_line.qty >= 0`, `sign ∈ {-1,0,1}`.

2. **LiquidHaskell-инварианты**:
   - Тип `TechLine` (часть `Core.Production.Types`) с `qty >= 0`, `sign` из дискретного множества, `formula` не пустой для автоматических линий.
   - `WorkOrder` с `qtyPlanned >= qtyReleased`, `status` корректен (в перечислении `WorkOrderStatus`), `schedule` & `dates` согласованы (`scheduled_at <= start <= end`), `processor`/`goods` обязательно существует в домене.
   - `MRPRequirement` (тип Sec). `calcMRPNeed` должен доказывать, что суммарный спрос равен сумме потребного ранее минус уже выделенные запасы (инвариант `Σ need >= 0`).

3. **Hasql и Stored procedures**:
   - Внести функции `create_tech_card`, `create_tech_line`, `find_auto_tech(cards)`, `reserve_mrp_requirements`, `release_work_order`, `complete_work_order`. Они должны включать `RAISE EXCEPTION` при нарушениях (наличие дублей, нехватка ресурсов, неоднозначный статус).
   - Добавить процедуры, моделирующие `BillCore::Post` для WorkOrder (создание `acc_turn`/`stock_movement`, обновление `lot`). Вызов `calc_stock_balance`/`fifo_select_lots` уже есть — надо адаптировать.

4. **API/QML/JobServer**:
   - Расширить `DB.Production`/`Domain.Production` на новые endpoints: `GET /production/work-orders`, `POST /production/work-orders`, `POST /production/work-orders/:id/release`, `POST /production/work-orders/:id/complete`, `GET /production/tech`.
   - Добавить JWT-мидлвар, логирование, property tests (например, проверка, что суммарный `qty_released <= qty_plan`).
   - JobServer: `job`-типы `production_release`, `production_snapshot`. `DB.JobQueue.enqueueJob` должен запускать MRP-джобы (генерация Jasper/Pentaho/Helical `production_mrp.jrxml`).
   - QML: создать раздел “Production” с формами `TechCard`, `WorkOrder`, визуализация `MRP graph`.

5. **Reports**:
   - Jasper/Pentaho: `production_mrp.jrxml`, `work_order_status.jrxml`, `tech_card_bom.jrxml`.
   - JobServer => `report_render` job `production_work_order`, `production_capacity`.
   - Интеграция `Reports` (REST: `/reports`, `/reports/:name`), `Reports.ReportDef` → SQL/HR result via `calc_stock_balance`/`get_lot_bounds`.

## 3. Связь с Hardware
- `Hardware` (например, `PPObjProcessor`, `PPObjProcessorConfig`) задаёт ресурсы, которые включают машины и инструменты (`processor` + `tech`).
- Нужно связать `tech_card.processor_id` с Hardware (эмулировать `PPProcessor` и `PPProcessorConfig`), включая атомарную генерацию кода (`TecCounter` → `tech_counter`), чтобы Surypus мог формировать заявки на машины.
- Добавить таблицу `hardware_resource`, `hardware_schedule` (для планирования), инварианты: ресурс не используется одновременно двумя заказами, `scheduled_at` + `occupied_until` согласованы.

## 4. Проверки и CI
- QuickCheck: `prop_release_not_exceed_plan`, `prop_tech_qty_nonneg`, `prop_mrp_conservation`.
- Интеграции: `stack test --test-arguments "--match Production"` и `--match HR` (после стабилизации `vector`/`directory`).
- CI (`.github/workflows/ci.yml`) обязуется: сборка, тесты, отчёты, `stack exec scripts/check_schema_uniqueness.sh`, `stack exec hindent`, `stack exec hlint`.

## 5. Следующие задачи
1. Описать таблицы/schemas (см. `config/schema_production.sql`, `config/schema_tech.sql`), добавить миграции `init_db.sh`.
2. Реализовать `Core.Production.Types`/`Domain.Production` с LiquidHaskell-типами, `DB.Production` (Hasql) и API/QML/JobServer.
3. Написать отчёты Jasper/Pentaho/Helical, job-джобы, property tests.
4. После каждого блока добавлять документацию в `docs/engineering` и фиксировать прогон `stack test` (и eventual `stack test --match Production`).
