# Module 02 — HR / Payroll

*Следующий крупный модуль после документов — управление персоналом и расчёт заработной платы: правила валидности начислений и взаимосвязь с бухгалтерскими документами уже описаны в исходной реализации (`salary.cpp`, `Objstaff.cpp`, `v_staff.cpp`).*

## 1. Анализ
- `SalaryCore::Validate` требует: числа идентификаторов положительные, `Beg <= End`, `Amount` в пределах серебряной десяти, `Flags == 0`, ссылки на счета (`LinkBillID`, `GenBillID`, `RByGenBill`) в допустимом диапазоне.
- `SalaryCore::Put` блокирует пересечение периодов с теми же `PostID` + `SalChargeID`, чтобы не было двух записей за один период. Если найдена запись с точным совпадением периода, она обновляется, иначе вставляется новая.
- `Calc()` суммирует суммы по заданному `PostID` + `SalChargeID` и может возвращать как абсолютную сумму, так и среднее (`avg` флаг). `GetListByObject` и др. — это фильтры для отчётов.

## 2. Что уже есть в Surypus
- Схема HR (`config/schema_hr.sql`) содержит таблицы отделов, должностей и сотрудников, а уже существующие функции (`hire_employee`, `calc_emp_salary`).
- Нет таблиц зарплатных начислений и прикладной логики, которая защищает от перекрытия периодов, разносит начисления по сотрудникам и связывает их с документами.

## 3. План переноса / уникализации
1. **SQL-схемы**: добавить `schema_hr_salary.sql` с таблицами `hr_salary`, `hr_salary_charge`, `hr_salary_link` и индексы. Уникальность — `(employee_id, charge_id, period_start, period_end)` и `CHECK (period_start <= period_end)`.
2. **LiquidHaskell-модули**: создать `Core.HR.Types` и `Domain.HR` с типами `SalaryRecord`, `SalaryCharge`, `PayPeriod`, `EmployeeSalarySummary`. Внедрить инварианты `amount >= 0`, `period_start <= period_end`, `charge_id > 0`, `non-overlapping` (для записей в одном вызове) и `calcPeriodSum`.
3. **Stored procedures**: расширить `sql/procedures.sql` с `create_salary_record`, `calc_salary_sum`, `hr_payroll_summary`, `resolve_salary_overlap` (с `RAISE EXCEPTION` при дублировании). Добавить `HASQL` обёртки `DB.Payroll`.
4. **Hasql/Domain/API**: добавить модуль `DB.Payroll` с `listSalaryRecords`, `createSalaryRecord`, `getSalarySummary`. Обновить `APIServer` (JWT-миддлваре) маршрут `/api/v1/hr/salaries` (GET, POST) и `/api/v1/hr/payrolls/summary`, а также `hrRoutes` для должностей/сотрудников с CRUD.
5. **QML/Reports/CI/test**: добавить QML-формы для `HR → Сотрудники → Начисления`, Jasper-отчёт `payroll_summary.jrxml`, и property-based тесты `Domain.HR` (наличие неотрицательных сумм, корректный период). Добавить CI-шаг `stack test --fast` включающий HR-тесты.
6. **Документация**: описать API, SQL хранимые процедуры, invariants LiquidHaskell; обновить `README` и `docs/engineering`.

## 4. Интеграция
- Поддерживать связи `SalaryTbl::LinkBillID` → `bill.id` через Hasql и `LinkBill` (экспорт `DB.Bill`/`DB.Payroll`).
- Повторно использовать `employee`/`department`/`position` из `schema_hr.sql` и HR API (т.е. новые `hrRoutes` должны опираться на эти таблицы). 
- Отчёты `Salary` должны быть переписаны в Jasper+Pentaho, а не использовать Crystal Reports.

## 5. Следующие действия (немедленные)
1. Создать `schema_hr_salary.sql` + записать новые функции в `sql/procedures.sql`.
2. Реализовать `Core.HR.Types` и `Domain.HR` с LiquidHaskell.
3. Добавить `DB.Payroll`, `APIServer.hrRoutes` + JWT, и протестировать `Domain.HR`.
4. Обновить документацию и запуск `init_db.sh`/`init_schema` для новых объектов.

## 6. Property-based проверки

Чтобы убедиться, что базовые invariants с заработной платой сохраняются, в `test/Domain/HRSpec` добавлены QuickCheck-свойства:

* `calcSalaryPerDay` × количество дней ≈ сумма за период (с учётом округлений `clampNonNeg`);
* `calcSalaryPerDay` никогда не даёт отрицательных значений;
* `validateSalaryRecord` работает при любых неотрицательных суммах и корректных периодах.

Эти свойства покрывают те же правила, что и `SalaryCore::Calc`, но в терминах LiquidHaskell-типов, поэтому любые будущие изменения обязательно должны проходить через `stack test --test-arguments "--match HR"` и через property-based проверку (в CI).
