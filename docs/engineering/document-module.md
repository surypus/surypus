# Документальный модуль Surypus

## 1. Что делает оригинальная реализация

- `PPObjRegister` и `PPObjRegisterType` описывают регистры документов, их типы и флаги `REGTF_*` (`UNIQUE`, `DUPNUMBER`, `ONLYNUMBER`, `LOCATION`, `WARNEXPIRY` и др.).  
  Регистры называются по номеру `Num`, привязаны к объектам (`PPOBJ_PERSON` / `PPOBJ_LOCATION`) и, при необходимости, требуют уникальности номера (`CheckUniqueNumber`), учитывают тип объекта и предупреждают об истечении срока (`REGTF_WARNEXPIRY`).  
- При создании регистра (`PPObjRegister::HandleMsg`, `Helper_EditDialog`) система подбирает `RegType`, автоматически вычисляет даты (`ExpiryPeriod`), переводит пользователя на ввод только номера (`REGTF_ONLYNUMBER`) и запрещает дублирование номеров по типу, если у типа нет `REGTF_DUPNUMBER`.  
- Номера регистров получают из хранимой процедуры `document_get_next_register_number` (`config/schema_Core_Document_Register.sql`), а проверки концентрации выполняются функцией `document_register_number_exists`.  
- Отдельно существует счётчик документов (`document_op_counter` / `document_get_next_doc_number`) для операций (`objregt.cpp` и `config/schema_Core_Document_OpCounter.sql`), которые формируют номера документов через префикс и флаг `REGTF_DUPNUMBER`.

## 2. Как это отражено в Surypus

- `Core.Document.Types` теперь экспортирует `DocumentRegisterFlag` и вспомогательные предикаты (`documentRegisterTypeAllowsDuplicateNumbers`, `documentRegisterTypeOnlyNumber`, `documentRegisterTypeForLocation` и др.), которые соответствуют `REGTF_*` и позволяют верифицировать бизнес-инварианты на уровне LiquidHaskell.  
- `DB.Document.Register` загружает тип (`DB.Document.RegisterType.getRegisterType`) и запускает `checkDuplicate`, который использует новые предикаты, чтобы повторно применять условие `REGTF_DUPNUMBER` из C++.  
- `DB.Document.RegisterType` и `DB.Document.Counter` продолжают хранить размеры (код, флаги, префиксы), а API в `APIServer.documentRoutes` предоставляет CRUD + генерацию следующего номера, как в интерфейсах `PPObjRegisterType`.  
- SQL-модули (`config/schema_Core_Document_*`) отделяют `Core.Document` и `PPObjRegister`, и `docs/engineering/schema-uniqueness.md` содержит описание, почему коллизии `AccSheet`/`OpCounter` разобраны.

## 3. Потоки данных, сохранённые в Surypus

1. **Создание регистра:** контролируется `validateDocumentRegister`, `resolveNumber`, `documentRegisterTypeAllowsDuplicateNumbers`.  
2. **Номер документа:** при `drAutoNumber` вызывается `document_get_next_register_number`, потом `checkDuplicate` проверяет, не нарушает ли флаг `REGTF_DUPNUMBER`.  
3. **Тип документа:** `documentOpCounter` сгенерирует номер через `document_get_next_doc_number`, в `APIServer` уже есть endpoint `/documents/counters/:id/next-number`.

## 4. Следующие шаги, чтобы завершить портирование

- Подключить флаги `REGTF_WARNEXPIRY` / `REGTF_WARNABSENCE` к API и Domain, чтобы при запросе регистра фронтенд мог подсветить статус (например в QML показать “истекает/нет” по `documentRegisterStatusAsOf`).  
- Расширить job-сервер `Surypus/Surypus/JobRunner.hs`, чтобы асинхронно запускать `document_register_audit` (новая задача), которая проверяет немедленно истекающие регистры и повторяющиеся номера на стороне PostgreSQL (`DB.Document.Audit`).  
- Добавить новый REST-некрон `/api/v1/documents/audit`, который создает джоб `document_register_audit` с любым `lookaheadDays` (по умолчанию 30), чтобы UI/ETL могли запускать аудит по расписанию или при импорте данных.
- Перенести CrystalReports (структуры `document_register`, `document_op_counter`) в Jasper/Pentaho/Helical, чтобы отчёты ссылались на те же SQL-функции (например, `document_get_next_register_number` будет источником `document_number`).

Документальный модуль Surypus теперь опирается на новую формализацию флагов и сохранённые SQL-функции. Следующий тикет — завершить UI/ETL/отчёты, оперируя этими invariants.
