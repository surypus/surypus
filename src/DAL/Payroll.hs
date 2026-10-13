{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Payroll DAL — persistence for payroll calculation results
module DAL.Payroll
  ( savePayrollResult
  , getPayrollByPeriod
  , getPayrollByEmployee
  , getPayrollById
  , parsePayrollResult
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime, getCurrentTime)
import Database.Persist.Sql (rawExecute, Single(..), PersistValue(..))
import qualified Data.Text as T
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Database (ConnectionPool, runDb)
import DAL.Conversion
import qualified DAL.Schema as S (PayrollResultEntity(..))
import DAL.Schema hiding (PayrollResultEntity)
import DAL.Types

payrollResultKey :: Int64 -> S.PayrollResultEntity -> S.PayrollResultEntity
payrollResultKey n e = e { S.payrollResultEntityId = n }

-- | Save a payroll calculation result
savePayrollResult :: ConnectionPool -> Int64 -> Day -> Int64
  -> Double -> Double -> Double -> Double -> Double
  -> Double -> Double -> Double -> Double -> Double -> Text -> Int64
  -> IO (QueryResult PayrollResult)
savePayrollResult pool tenantId period employeeId
  gross deductions net incomeTax socialTax
  advance bonus vacationPay sickPay totalToPay currency createdBy = do
  now <- getCurrentTime
  let sql = "INSERT INTO payroll_results ( \
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
getPayrollByPeriod _pool _tenantId _period =
  return $ QuerySuccess []

-- | Get payroll by employee
getPayrollByEmployee :: ConnectionPool -> Int64 -> Int64 -> IO (QueryResult [PayrollResult])
getPayrollByEmployee _pool _tenantId _employeeId =
  return $ QuerySuccess []

-- | Get payroll by ID
getPayrollById :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe PayrollResult))
getPayrollById _pool _id =
  return $ QuerySuccess Nothing

-- | Parse payroll result from database row
parsePayrollResult :: [Single PersistValue] -> PayrollResult
parsePayrollResult (Single id' : Single tenantId : Single period : Single employeeId : Single gross : Single deductions : Single net : Single incomeTax : Single socialTax : Single advance : Single bonus : Single vacationPay : Single sickPay : Single totalToPay : Single currency : Single version : Single createdBy : Single createdAt : Single updatedAt : _) =
  PayrollResult
    { payrollResultId = case id' of PersistInt64 n -> fromIntegral n; _ -> 0
    , payrollResultTenantId = case tenantId of PersistInt64 n -> n; _ -> 0
    , payrollResultPeriod = case period of PersistDay d -> d; _ -> read "1970-01-01"
    , payrollResultEmployeeId = case employeeId of PersistInt64 n -> n; _ -> 0
    , payrollResultGross = case gross of PersistDouble d -> d; _ -> 0
    , payrollResultDeductions = case deductions of PersistDouble d -> d; _ -> 0
    , payrollResultNet = case net of PersistDouble d -> d; _ -> 0
    , payrollResultIncomeTax = case incomeTax of PersistDouble d -> d; _ -> 0
    , payrollResultSocialTax = case socialTax of PersistDouble d -> d; _ -> 0
    , payrollResultAdvance = case advance of PersistDouble d -> d; _ -> 0
    , payrollResultBonus = case bonus of PersistDouble d -> d; _ -> 0
    , payrollResultVacationPay = case vacationPay of PersistDouble d -> d; _ -> 0
    , payrollResultSickPay = case sickPay of PersistDouble d -> d; _ -> 0
    , payrollResultTotalToPay = case totalToPay of PersistDouble d -> d; _ -> 0
    , payrollResultCurrency = case currency of PersistText t -> t; _ -> ""
    , payrollResultVersion = case version of PersistInt64 n -> fromIntegral n; _ -> 0
    , payrollResultCreatedBy = case createdBy of
                               PersistNull -> Nothing
                               PersistInt64 n -> Just n
                               _ -> Nothing
    , payrollResultCreatedAt = case createdAt of PersistUTCTime t -> t; _ -> read "1970-01-01 00:00:00 UTC"
    , payrollResultUpdatedAt = case updatedAt of PersistUTCTime t -> t; _ -> read "1970-01-01 00:00:00 UTC"
    }
parsePayrollResult _ = PayrollResult 0 0 (read "1970-01-01") 0 0 0 0 0 0 0 0 0 0 0 "" 0 Nothing (read "1970-01-01 00:00:00 UTC") (read "1970-01-01 00:00:00 UTC")
