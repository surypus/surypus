{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Payroll DAL — persistence for payroll calculation results
module DAL.Payroll
  ( savePayrollResult
  , getPayrollByPeriod
  , getPayrollByEmployee
  , getPayrollById
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime, getCurrentTime)
import Database.Persist.Sql (toSqlKey, rawSql, rawExecute, Single(..), PersistValue(..), PersistDay)
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Database (ConnectionPool, runDb)
import DAL.Conversion
import DAL.Schema
import DAL.Types

payrollResultKey :: Int64 -> Key PayrollResultEntity
payrollResultKey n = toSqlKey n

-- | Save a payroll calculation result
savePayrollResult :: ConnectionPool -> Int64 -> Day -> Int64
  -> Double -> Double -> Double -> Double -> Double
  -> Double -> Double -> Double -> Double -> Double -> Text -> Int64
  -> IO (QueryResult PayrollResult)
savePayrollResult pool tenantId period employeeId
  gross deductions net incomeTax socialTax
  advance bonus vacationPay sickPay totalToPay currency createdBy = do
  now <- getCurrentTime
  let sql = "INSERT INTO payroll_results (\
            \  tenant_id, period, employee_id, gross, deductions, net, \
            \  income_tax, social_tax, advance, bonus, vacation_pay, sick_pay, \
            \  total_to_pay, currency, version, created_by, created_at, updated_at) \
            \VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)"
  runDb pool $ rawExecute sql
    [ PersistInt64 tenantId
    , PersistDay period
    , PersistInt64 employeeId
    , PersistDouble gross
    , PersistDouble deductions
    , PersistDouble net
    , PersistDouble incomeTax
    , PersistDouble socialTax
    , PersistDouble advance
    , PersistDouble bonus
    , PersistDouble vacationPay
    , PersistDouble sickPay
    , PersistDouble totalToPay
    , PersistText currency
    , PersistInt64 createdBy
    , PersistUTCTime now
    , PersistUTCTime now
    ]
  return $ QuerySuccess $ PayrollResult
    { payrollResultId = 0
    , payrollResultTenantId = tenantId
    , payrollResultPeriod = period
    , payrollResultEmployeeId = employeeId
    , payrollResultGross = gross
    , payrollResultDeductions = deductions
    , payrollResultNet = net
    , payrollResultIncomeTax = incomeTax
    , payrollResultSocialTax = socialTax
    , payrollResultAdvance = advance
    , payrollResultBonus = bonus
    , payrollResultVacationPay = vacationPay
    , payrollResultSickPay = sickPay
    , payrollResultTotalToPay = totalToPay
    , payrollResultCurrency = currency
    , payrollResultVersion = 1
    , payrollResultCreatedBy = Just createdBy
    , payrollResultCreatedAt = now
    , payrollResultUpdatedAt = now
    }

-- | Get payroll by period
getPayrollByPeriod :: ConnectionPool -> Int64 -> Day -> IO (QueryResult [PayrollResult])
getPayrollByPeriod pool tenantId period = do
  let sql = "SELECT id, tenant_id, period, employee_id, gross, deductions, net, \
            \  income_tax, social_tax, advance, bonus, vacation_pay, sick_pay, \
            \  total_to_pay, currency, version, created_by, created_at, updated_at \
            \FROM payroll_results WHERE tenant_id = ? AND period = ?"
  rows <- runDb pool $ rawSql sql [PersistInt64 tenantId, PersistDay period]
  return $ QuerySuccess $ map parsePayrollResult rows

-- | Get payroll by employee
getPayrollByEmployee :: ConnectionPool -> Int64 -> Int64 -> IO (QueryResult [PayrollResult])
getPayrollByEmployee pool tenantId employeeId = do
  let sql = "SELECT id, tenant_id, period, employee_id, gross, deductions, net, \
            \  income_tax, social_tax, advance, bonus, vacation_pay, sick_pay, \
            \  total_to_pay, currency, version, created_by, created_at, updated_at \
            \FROM payroll_results WHERE tenant_id = ? AND employee_id = ?"
  rows <- runDb pool $ rawSql sql [PersistInt64 tenantId, PersistInt64 employeeId]
  return $ QuerySuccess $ map parsePayrollResult rows

-- | Get payroll by ID
getPayrollById :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe PayrollResult))
getPayrollById pool id' = do
  let sql = "SELECT id, tenant_id, period, employee_id, gross, deductions, net, \
            \  income_tax, social_tax, advance, bonus, vacation_pay, sick_pay, \
            \  total_to_pay, currency, version, created_by, created_at, updated_at \
            \FROM payroll_results WHERE id = ?"
  rows <- runDb pool $ rawSql sql [PersistInt64 id']
  case rows of
    (row : _) -> return $ QuerySuccess $ Just $ parsePayrollResult row
    _ -> return $ QuerySuccess Nothing

-- | Parse payroll result from database row
parsePayrollResult :: [PersistValue] -> PayrollResult
parsePayrollResult (Single id' : Single tenantId : Single period : Single employeeId : Single gross : Single deductions : Single net : Single incomeTax : Single socialTax : Single advance : Single bonus : Single vacationPay : Single sickPay : Single totalToPay : Single currency : Single version : Single createdBy : Single createdAt : Single updatedAt : _) =
  PayrollResult
    { payrollResultId = read $ show id'
    , payrollResultTenantId = read $ show tenantId
    , payrollResultPeriod = read $ show period
    , payrollResultEmployeeId = read $ show employeeId
    , payrollResultGross = read $ show gross
    , payrollResultDeductions = read $ show deductions
    , payrollResultNet = read $ show net
    , payrollResultIncomeTax = read $ show incomeTax
    , payrollResultSocialTax = read $ show socialTax
    , payrollResultAdvance = read $ show advance
    , payrollResultBonus = read $ show bonus
    , payrollResultVacationPay = read $ show vacationPay
    , payrollResultSickPay = read $ show sickPay
    , payrollResultTotalToPay = read $ show totalToPay
    , payrollResultCurrency = T.pack $ show currency
    , payrollResultVersion = read $ show version
    , payrollResultCreatedBy = if T.null (T.pack $ show createdBy) then Nothing else Just (T.pack $ show createdBy)
    , payrollResultCreatedAt = read $ show createdAt
    , payrollResultUpdatedAt = read $ show updatedAt
    }
parsePayrollResult _ = PayrollResult 0 0 (read "1970-01-01") 0 0 0 0 0 0 0 0 0 0 0 "" 0 Nothing (read "1970-01-01 00:00:00 UTC") (read "1970-01-01 00:00:00 UTC")
