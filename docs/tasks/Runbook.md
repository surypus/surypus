# Runbook: тестирование Surypus

Проект **Surypus** — тестирование ведётся на Haskell с помощью **Hspec** (unit-тесты)
и **QuickCheck** (property-based тесты). Полный набор тестов — тестовая коллекция
`surypus-test` (main-файл `test/Test.hs`, 77 модулей в тест-сборке).

## 1. Быстрый старт

| Действие | Команда |
|---|---|
| Собрать тестовую коллекцию | `cabal build test:surypus-test` |
| Запустить весь набор | `cabal test surypus-test` |
| Запустить с подробным логом | `cabal test surypus-test --test-show-details=direct` |
| Один тест по имени | `cabal test surypus-test --test-options="--match 'VAT'"` |
| Один spec-файл | `cabal test surypus-test --test-options="-m \"НДС 20%\""` |
| Собрать и запустить вместе | `cabal test surypus-test --test-options=--quiet` |

**Legacy-путь** (стек, documented in `DEVELOPMENT.md`):

```bash
stack test                    # весь набор
stack test --test-arguments "--match 'VAT'"
stack test --test-arguments "-m \"НДС 20%\""
```

Рекомендованная локальная среда: **GHC 9.10.3 + cabal-install 3.12.1.0**
(проект собирается через `cabal` в `dist-newstyle`; `stack.yaml` / `cabal.project`
(резитор lts-22.21) оставлены для вторичного пути).

## 2. Что запускается

Тест-сборка (`Surypus.cabal`, раздел `test-suite surypus-test`) включает 77 модулей:
unit-тесты hspec, property тесты QuickCheck и интеграционные тесты (блокирующиеся на
окружении). `test/Test.hs` импортирует основную часть модулей напрямую; те модули,
которые требуют окружения, подключаются транзитивно от тест-обёрток
(`DAL.EventStoreIntegration`, `Infrastructure.Redis.EventStreamSpec`,
`Infrastructure.EventStore.AccountingIntegration`).

## 3. Блокеры тестовой базы (3 pending)

Интеграционные тесты запускаются только при наличии переменных окружения.
Без них они отмечаются `pendingWith` (не считаются ошибкой, заносятся в `pending`
и не снижают стабильность CI).

| Модуль | Переменная | Что требуется |
|---|---|---|
| `DAL.EventStoreIntegration` | `SURYPUS_TEST_DATABASE_URL` | PostgreSQL (пул из 2 коннекта) |
| `Infrastructure.Redis.EventStreamSpec` | `SURYPUS_TEST_REDIS_URL` | Redis (stream fan-out) |
| `Infrastructure.EventStore.AccountingIntegration` | `SURYPUS_TEST_DATABASE_URL` + `SURYPUS_TEST_REDIS_URL` | обе выше |

Пример установки для локального запуска (PostgreSQL 16+, Docker):

```bash
export SURYPUS_TEST_DATABASE_URL=postgresql://test:test@localhost:5432/surypus_test
export SURYPUS_TEST_REDIS_URL=redis://localhost:6379/0
cabal test surypus-test
```

Проверено на локальной машине без окружения: **1139 examples, 0 failures, 3 pending**
(exit code 0), что соответствует ожидаемому стabe-состоянию.

## 4. Добавление нового spec-файла

Для расширения покрытия (классический паттерн: `Surypus-6xx` — QuickCheck property
spec для чистых модулей):

1. Создать `test/<Path>/<Module>Spec.hs`:

   ```haskell
   {-# LANGUAGE OverloadedStrings #-}
   module <Path.Module>Spec (spec) where
   -- ...
   spec :: Spec
   spec = do
     describe "something" $ do
       it "pinned behaviour" $ ...
       prop "property name" prop_something
   ```

2. Добавить модуль в тест-сборку в `Surypus.cabal`:

   ```cabal
   test-suite surypus-test
     ...
     other-modules:
       ...
       <Path.Module>Spec
   ```

3. Добавить импорт в `test/Test.hs`:

   ```haskell
   import qualified <Path.Module>Spec
   ```
   и добавить `<Path.Module>Spec.spec` в `main = hspec $ do`.

4. Пересобрать и прогнать: `cabal build test:surypus-test && cabal test surypus-test`.
   Секция QuickCheck выводит `+++ OK, passed 100 tests.` для свойств.

## 5. Чтение результатов

| Результат | Значение |
|---|---|
| `N examples, 0 failures, 3 pending` | stabilise: тесты зелёные, pending — только интеграционные блоки |
| `+++ OK, passed 100 tests.` | QuickCheck-свойство прошло 100 прогонов |
| `Falsified` / `Failure` | регрессия — смотреть `*.log` в `dist-newstyle/.../t/surypus-test/` |
| `pendingWith` в выводе теста | ожидаемое, без env vars (см. §3) |

Логи: `dist-newstyle/build/x86_64-linux/ghc-9.10.3/Surypus-0.1.0.0/t/surypus-test/test/`
(имя исполняемого файла `Surypus-0.1.0.0-surypus-test.log`).

## 6. Версии и известные блокеры

- **GHC 9.10.3 + cabal 3.12.1.0** — основная локальная среда (проверено 2026-11-18).
- `stack.yaml` / `cabal.project` (lts-22.21) — вторичный путь; на GHC 9.6.5
  (`Nix`/`stack`) известна проблема с `hashtables` C-компиляцией
  (`Surypus-3k7`, P1) — не затрагивает среду cabal выше.
- Интеграционные тесты без `SURYPUS_TEST_DATABASE_URL` / `SURYPUS_TEST_REDIS_URL`
  всегда показывают 3 pending — это нормальное состояние, а не регрессия.
