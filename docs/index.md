# Surypus ERP

ERP/CRM система полного цикла на Haskell: формальная верификация, типобезопасный
доступ к данным, event sourcing.

## Разделы

| Раздел | Описание |
|---|---|
| [Архитектура](ARCHITECTURE.md) | Слои системы, схема данных, event sourcing |
| [Система типов](TYPES.md) | Типобезопасная модель предметной области |
| [API](API.md) | REST API и его соглашения |
| [Хранилище данных](DATABASE.md) | Схема PostgreSQL и миграции |
| [Развёртывание](DEPLOYMENT.md) | Сборка и запуск в production |
| [Руководство](GUIDE.md) | Практическое руководство по работе с системой |

## Задачи

Список задач ведётся в [beads](https://github.com/steveyegge/beads) и
зеркалится сюда автоматически:

- [Обзор задач](tasks/Home.md) — источники данных и сводка
- [Планы](tasks/Plans.md) — активные задачи
- [Бэклог](tasks/Backlog.md) — закрытые задачи

## Разработка

- [Как работает бухгалтерия](guides/accounting.md)
- [Как работает инвентарь](guides/inventory.md)
- [Как работает RBAC](guides/rbac.md)
- [Как работает JWT-аутентификация](guides/jwt.md)
- [Как работает персистентность](guides/persistence.md)
- [Как работает Event Store](guides/event-store.md)

## Репозиторий

- Код: <https://github.com/surypus/surypus>
- Задачи: <https://github.com/surypus/surypus/issues>
- Проект: <https://github.com/orgs/surypus/projects/2>
- База задач: <https://www.dolthub.com/repositories/dominicusin/Surypus-bd>
