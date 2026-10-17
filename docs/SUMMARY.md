# Surypus ERP — Сводная документация

> Единая точка входа в документацию проекта. Для разработчиков, администраторов и бизнес-пользователей.

## О проекте

**Surypus** — ERP-система полного цикла на Haskell с формальной верификацией. Охватывает складской учёт, бухгалтерию, налоги, закупки, продажи, производство, HR/зарплату и CRM.

| Аспект | Значение |
|--------|----------|
| Язык | Haskell 2010 (GHC 9.6.5) |
| Сборка | Stack (resolver lts-22.21) |
| База данных | PostgreSQL 16 |
| API | REST (Servant) + GraphQL |
| Веб-клиент | Vanilla JS (index.html, api.js) |
| Лицензия | GPL-3.0-or-later |
| Исходники | ~275+ модулей, 37 директорий |

## Структура документации

| Раздел | Для кого | Содержание |
|--------|----------|------------|
| [Архитектура и бизнес-контекст](ARCHITECTURE.md) | Все | C4-контекст, ADR, DDD, бизнес-домены |
| [Система типов и Haskell](TYPES.md) | Разработчики | Типы предметной области, эффекты, монады, конкурентность |
| [API-спецификация](API.md) | Разработчики, интеграторы | Все эндпоинты, модули, форматы |
| [Хранилище данных](DATABASE.md) | Разработчики, DBA | ER-схема, миграции, ACID |
| [Развёртывание и CI/CD](DEPLOYMENT.md) | DevOps | Сборка, Docker, мониторинг |
| [Руководство](GUIDE.md) | Администраторы, пользователи | RBAC, backup, сценарии работы |

## Связанные документы (существующие)

### Корень проекта

| Файл | Описание |
|------|----------|
| `README.md` | Быстрый старт: сборка, тесты, запуск |
| `CONTRIBUTING.md` | Правила для контрибьюторов |
| `AGENTS.md` | Инструкция для AI-агентов (build, тесты, стиль) |
| `ARCHITECTURE.md` | Формальная верификация, C++→Haskell маппинг |
| `API_DOCUMENTATION.md` | REST API (плоский список эндпоинтов) |
| `RBAC.md` | Ролевая модель и права доступа |
| `DEVELOPMENT.md` | Настройка окружения разработчика |
| `OPERATIONS.md` | Эксплуатация и деплой |
| `ENV_VARS.md` | Переменные окружения |
| `Makefile` | Автоматизация сборки (135 целей) |
| `STRUCTURE.md` | Структура кода |
| `STATE.md` | Текущее состояние проекта |
| `ROADMAP.md` | План развития |
| `STRATEGY.md` | Долгосрочная стратегия |
| `PLANNING.md` | Планирование |
| `TASKS.md` | Отслеживание задач |
| `TODO.md` | Список задач |

### `docs/` директория

| Файл | Описание |
|------|----------|
| `architecture/EVENT_SOURCING.md` | Event Sourcing и CQRS архитектура |
| `engineering/api-conventions.md` | Соглашения по REST API |
| `engineering/bill-module.md` | Проектирование модуля счетов |
| `engineering/document-module.md` | Документооборот |
| `engineering/hr-payroll-module.md` | HR и зарплата |
| `engineering/job-server-etl.md` | Job-сервер и ETL |
| `engineering/person-module.md` | Модуль контрагентов |
| `engineering/production-module.md` | Производственный модуль |
| `engineering/reports-portal.md` | Генерация отчётов |
| `engineering/schema-uniqueness.md` | Уникальность схемы БД |
| `engineering/testing-guide.md` | Руководство по тестированию |
| `examples/EXAMPLES.md` | Примеры использования (SQL, Haskell, cURL) |
| `haddock/Domain-Person.md` | Haddock-документация типов Person |
| `scientific_object/main.pdf` | Научный PDF-документ |

### База данных

| Расположение | Описание |
|--------------|----------|
| `sql/migrations/` | 370+ файлов миграций (V000–V999) |
| `sql/docs/ARCHITECTURE.md` | Архитектура SQL-слоя |
| `sql/docs/RBAC_CANON.md` | Каноническая RBAC-модель |
| `sql/docs/AUDIT.md` | Аудит БД |
| `sql/docs/CHANGELOG.md` | История изменений SQL |
| `sql/procedures/` | Хранимые процедуры |
| `sql/projection/` | Проекции Event Sourcing |
| `sql/event/` | События |

## Быстрые ссылки

```bash
# Сборка и тесты
stack build
stack test                    # 76 тестов
stack test --match "VAT"      # Выборочный тест

# Запуск
stack run                     # API-сервер на порту 443

# REPL
stack repl

# База данных
psql -h localhost -U surypus -d surypus

# Docker
docker compose up -d
```

## Навигация по исходникам

```
src/
├── Core/              # Бизнес-логика (налоги, товары, accounting, склад)
│   └── Services/      # Сервисный слой (Accounting.hs)
├── DAL/               # Доступ к данным (Persistent, Esqueleto)
├── Surypus/
│   ├── API/           # 26 хендлеров REST API
│   ├── JWT/           # Аутентификация (JWT)
│   ├── RBAC/          # Ролевая модель
│   ├── Types/         # Типы для API (Auth, Bill, Goods, Stock...)
│   └── Reports/       # Генерация отчётов (PDF)
├── Infrastructure/    # EventStore, Redis
├── Integration/       # Внешние интеграции (API EventStore)
├── Inventory/         # Складской учёт
├── Finance/           # Финансовые расчёты
├── HR/                # HR и зарплата
├── CRM/               # Клиенты и сделки
├── Production/        # Производство
├── Reports/           # Отчёты
├── Security/          # Безопасность
└── MultiTenancy/      # Мультиарендность
```
