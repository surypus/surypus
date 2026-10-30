# Walking Skeleton — Surypus ERP

**Phase:** 1
**Generated:** 2026-10-23

## Capability Proven End-to-End

> Один оператор поднимает сервер одной командой на реальном PostgreSQL, а `GET /api/v1/health` отвечает 200 только когда база действительно доступна; схема собирается с нуля одной канонической командой миграций.

Это наименьший пользовательский сценарий, который проходит через все слои фазы: env → конфигурация → пул соединений → HTTP-сервер → запрос к БД → ответ. Он же является приёмочным сигналом BOOT-01/BOOT-02 и предпосылкой для BOOT-03/BOOT-04.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Язык и компилятор | Haskell, GHC 9.6.5, Stackage LTS 22.21 | Зафиксировано `stack.yaml`; один тулчейн во всех конфигурациях (BOOT-06) |
| Сборка | stack | Единственный реально используемый build path; `cabal.project` — декларация тулчейна, не альтернативная сборка |
| HTTP-слой | `warp` + `servant-server` | Уже реализован в `Surypus.API.Server` (тип `SurypusApi`); фаза только подключает его к процессу |
| База данных | PostgreSQL 16+ | CI и compose используют `postgres:16`; локально проверено на 18.6, фичи остаются 16-совместимыми |
| Схема | Канонический SQL-корпус `sql/migrations/` + checksum-леджер | SQL — единственный источник истины; ORM-автомиграции и dual-ledger отвергнуты |
| Миграции | `stack run -- migrate` (подкоманда единственного executable) | Один executable сохраняет буквальный `stack run`; runner не запускается автоматически при старте сервера |
| Тенант | `tenant_id BIGINT NOT NULL DEFAULT 0` | 115 legacy-UUID против 4 BIGINT и весь Haskell на `Int64`; `app.current_tenant_id()` возвращает `BIGINT` |
| Конфигурация | env: `DATABASE_URL`, `SURYPUS_JWT_SECRET`, `PORT`, `LOG_LEVEL` | Один `Config`, fail-fast со списком всех пропусков; `DB_*` — fallback на один релиз |
| Health | `GET /api/v1/health` → 200 `{"status":"ok","db":"ok"}` / 503 `{"status":"error","db":"down"}` | Константное тело, реальный `SELECT 1`, никаких деталей драйвера; совпадает с Docker `HEALTHCHECK` (`curl -f`) |
| Auth | default-deny заглушка `(\_ _ -> pure False)` до Phase 6 | Не выдавать случайный доступ; health намеренно вне auth-middleware как liveness |
| Layout | `app/Main.hs` — тонкий вход; `src/Surypus/{Config,DB,API}` — библиотека; `sql/migrations/` — канон | Повторяет существующее разделение и не создаёт второй executable |
| Deployment (dev) | `stack run` локально + CI на `postgres:16` | Docker в окружении недоступен; воспроизводимость обеспечивается CI и скриптами |
| UI | Нет в Phase 1 | Весь UI отнесён roadmap'ом к Phase 7; в скелете нет ни одного HTML-маршрута, и это осознанно |

## Stack Touched in Phase 1

- [x] Project scaffold — build (`stack`), тест-раннер (`hspec` в `surypus-test`), линт-гейт тулчейна (`scripts/check-toolchain.sh`)
- [x] Routing — реальный маршрут `GET /api/v1/health` (и алиас `/api/v1/health/db`)
- [x] Database — реальное чтение (`SELECT 1` в health) **и** реальная запись (DDL + строки ledger `surypus_schema_migrations` при `migrate`)
- [ ] UI — намеренно отсутствует в Phase 1 (Phase 7); интерактивных элементов нет
- [x] Deployment — документированный локальный полный запуск (`stack build` → `stack run -- migrate` → `stack run` → `curl -f`) и CI на реальном PostgreSQL

## Out of Scope (Deferred to Later Slices)

- Любой UI, HTMX-фрагменты, шаблоны, статические страницы — Phase 7.
- Аутентификация, сессии, роли, CSRF — Phase 6; в Phase 1 только default-deny заглушка.
- Деньги, НДС, проводки, склад, счета, платежи — Phase 2–5; в канонической схеме нет `journal_entries`, `chart_of_accounts`, outbox/DLQ и таблиц, которыми не пользуется код Phase 1.
- RLS-политики и принудительная изоляция тенантов — Phase 6; поле `tenant_id` присутствует, но политики не включены.
- Исправление или исполнение 359 legacy-миграций — корпус архивируется, а не ремонтируется.
- Удаление дублирующих pool-модулей (`DAL.Database`, `DAL.Pool`, `Surypus.DB.Pool`) — Phase 6.
- `Surypus.App.Main` (генератор SQL внутри библиотеки) — помечен как неисполняемый, удаление в более поздней фазе.
- Down-миграции, сиды предметных данных, автоматические миграции при старте сервера.
- Мультивалютность, партии/FIFO, зарплата, PDF/Excel — вне v1 (см. REQUIREMENTS.md Out of Scope).

## Subsequent Slice Plan

Каждая следующая фаза добавляет вертикальный срез поверх этого скелета, не меняя его архитектурных решений:

- Phase 2: один тип `Money` и один движок НДС; схема получает канонические денежные/налоговые колонки новой миграцией.
- Phase 3: `Finance.Ledger` и `App.Tx.runWrite`; одна транзакция на операцию, баланс проверяет БД.
- Phase 4: товары, контрагенты, склад; приход увеличивает остаток и даёт проводки в одной транзакции.
- Phase 5: счёт → оплата → проводки → пробный баланс по HTTP/JSON; smoke-тест сквозного пути.
- Phase 6: серверные сессии, Argon2id, три роли, default-deny на каждом маршруте (заменяет заглушку `(\_ _ -> pure False)`).
- Phase 7: HTMX-интерфейс поверх готовых сервисов; скелет не меняется, добавляется адаптер.
- Phase 8: блокирующие гейты — smoke, coverage, mutation check, LiquidHaskell.
