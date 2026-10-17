# Job Server / ETL

Surypus реализует надёжную очередь задач (JobServer), которая позволяет запускать ETL-работы, импорт/экспорт данных, генерацию отчётов и синхронизацию внешних систем (Меркурий, Честный Знак, WMS). Мы численно перенесли основные элементы:

1. **SQL-ядро**: `config/schema_job_server.sql` описывает таблицы `job`, `job_dependency`, `job_result` и просмотры очереди. Дополнительно, `DB.Connection.initSchema` создаёт упрощённую версию `job` с кодом (`code`), приоритетом, JSON-данными (`job_data`) и временными метками (`scheduled_at`, `started_at`, `completed_at`). Индексы по `status`/`priority` обеспечивают быстрый выбор.
2. **Hasql & домен**: `Domain.Job` описывает типы `JobRequest`, `JobRecord`, `JobFilter`, `JobStatus` и формальные инварианты (например, `priority ∈ [1,10]`, код/название/тип не пусты). `DB.JobQueue` связывает Hasql с таблицей, реализуя `enqueueJob`, `fetchPendingJob`, `listJobs`, `getJob`, `setJobStatus` и логирование (`service_events`). Также агрегируются зависимости из `job_dependency`, которые отражаются в `JobRecord.jobDependencies`, и добавлена функция `addJobDependency`.
3. **API**: `APIServer.jobRoutes` предоставляет REST:
   - `POST /api/v1/jobs` — создать задачу (валидируется `validateJobRequest`)
   - `GET /api/v1/jobs` — лента задач с фильтрацией по статусу и типу
   - `GET /api/v1/jobs/:id` — детализированная запись
   - `PATCH /api/v1/jobs/:id/status` — меняет статусы (`pending`, `running`, `completed`, `failed`, `cancelled`)
4. **QML UI**: `Surypus/qml/Main.qml` содержит новый раздел «Jobs», который отображает очередь задач, их статусы и ошибки, а также позволяет вручную обновлять список.
5. **ETL-подсистема**: JobServer регулярно запускает SQL-скрипты (`sql/procedures.sql`), выполняет Jasper/Pentaho/Helical отчёты и синхронизацию с PostgreSQL через триггеры (`schema_job_server.sql`). Интеграция с `core`-модулями делится через `job_data` и JSON-параметры, а `DB.JobQueue` позволяет продвинутому ETL-сценарию обрабатывать зависимости (`job_dependency`) и ошибки (через `error_message`).
6. **REST и UI**: появился endpoint `/api/v1/jobs/:id/dependencies`, а QML-приложение теперь умеет показывать зависимости и создавать их вручную, что упрощает планирование ETL-графов и отчётов (Jasper/Pentaho/Helical).
6. **Тесты и CI**: `test/Domain/JobSpec.hs` проверяет `validateJobRequest` и `jobStatusFromText`. GitHub Actions запускает `stack test`, обеспечивая контроль логики очереди.

В следующих итерациях планируется расширить JobServer:

* ETL-графы (наследование от `job_dependency`, расчёт `wait_time`)
* Интеграция с Jasper/Pentaho через REST-генераторы (`reports/`)
* Webhook и WebSocket нотификации о смене статуса задач
* Сервис-перехватчики для автоматического запуска `DB.JobQueue.fetchPendingJob` из внешних наблюдателей.

### Snapshot job и фоновый worker

Новый тип задачи `person_summary_snapshot` агрегирует данные из таблицы `person` (через `get_person_summary()`) и сохраняет их в `person_summary_snapshot`. Это позволяет Jasper/Pentaho/Helical строить исторические отчёты по контрагентам. Чтобы процесс регулярно выполнялся, добавлен standalone worker:

* `Surypus.JobRunner.processPendingJobs` вызывает `DB.JobQueue.fetchPendingJob`, помечает задачу `JobRunning`, запускает `run_person_summary_snapshot` и фиксирует статус (`completed`/`failed`). Логи попадают в `service_events`, чтобы мониторить ETL/репорты.
* `app/JobWorker.hs` и новый executable `surypus-job-worker` стартуют worker с интервалом `SURYPUS_JOB_INTERVAL` (по умолчанию 30 секунд). Скрипт `scripts/run_job_worker.sh` упрощает развёртывание в systemd/container.  
* API `POST /api/v1/persons/summary/snapshots` триггерит snapshot on-demand, а `GET /api/v1/persons/summary/snapshots` возвращает последние 20 срезов (`person_summary_snapshot`), что пригодно для QML/отчётов и Jasper/Pentaho/Helical.  

### Дальнейшие домены и ETL

Пока JobServer покрывает базовую обработку документов, следующая волна портирования должна:

1. **HR & Payroll** — перенести `salary`/`payroll` документы через `core/api` → `Hasql` → `postgreSQL` (первичный план в `docs/engineering/hr-payroll-module.md`), написать ETL-джобы для начислений (в Jasper/Pentaho/Helical) и добавить property-based tests на расчёт НДФЛ/ФОТ.
2. **Production & Hardware** — добавить `tech`/`work-order` потоки в `job_dependency`, обеспечить `ETL job` для MRP (с использованием `get_mrp_requirements()` в PostgreSQL) и перенести отчёты о производстве (`production_work_order`, `tech_story`).
3. **Reports & ETL pipeline** — каждая задача `report_render` должна фиксировать `report_template`, `filters`, `generated_at` и результат (PDF/JRXML/CSV); JobServer должен запускать `jasperreports`, `pentaho-kettle` и `helical` CLI через `job_payload["report_engine"]`.
4. **Job-side invariants** — расширить `Domain.Job` с LiquidHaskell-инвариантами: `jrPriority ∈ [1,10]`, `jrCode`/`jrName`/`jrType` не пусты, `jrPayload` валидный JSON. Эти инварианты затем проверяются до вставки `job` в очередь, включая `job_dependency`.

Следующие публикации будут включать:
* план перевода Crystal Reports → Jasper/Pentaho/Helical;
* документацию по `ETL job` dependencies и `DB.JobQueue` API;
* отчёт о тестах (unit, property-based, API, CI).
