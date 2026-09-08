{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DataKinds #-}

-- | Payroll DAL — persistence for payroll calculation results
module DAL.Payroll
  ( savePayrollResult
  , getPayrollByPeriod
  , getPayrollByEmployee
  , getPayrollById
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Decimal (Decimal)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime, getCurrentTime)
import Database.Esqueleto.Experimental
import qualified Database.Persist as P
import Database.Persist.Sql (runSqlPool, toSqlKey)
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Conversion
import DAL.Schema
import DAL.Types

payrollResultKey :: Int64 -> P.Key PayrollResultEntity
payrollResultKey n = toSqlKey n

-- | Save a payroll calculation result
savePayrollResult :: ConnectionPool -> Int64 -> Day -> Int64
  -> Decimal -> Decimal -> Decimal -> Decimal -> Decimal
  -> Decimal -> Decimal -> Decimal -> Decimal -> Decimal -> Text -> Int64
  -> IO (QueryResult PayrollResult)
savePayrollResult pool tenantId period employeeId
  gross deductions net incomeTax socialTax
  advance bonus vacationPay sickPay totalToPay currency createdBy = do
  now <- liftIO getCurrentTime
  let entity = PayrollResultEntity
        { payrollResultEntityTenantId = tenantId
        , payrollResultEntityPeriod = period
        , payrollResultEntityEmployeeId = employeeId
        , payrollResultEntityGross = realToFrac gross
        , payrollResultEntityDeductions = realToFrac deductions
        , payrollResultEntityNet = realToFrac net
        , payrollResultEntityIncomeTax = realToFrac incomeTax
        , payrollResultEntitySocialTax = realToFrac socialTax
        , payrollResultEntityAdvance = realToFrac advance
        , payrollResultEntityBonus = realToFrac bonus
        , payrollResultEntityVacationPay = realToFrac vacationPay
        , payrollResultEntitySickPay = realToFrac sickPay
        , payrollResultEntityTotalToPay = realToFrac totalToPay
        , payrollResultEntityCurrency = currency
        , payrollResultEntityVersion = 1
        , payrollResultEntityCreatedBy = Just createdBy
        , payrollResultEntityCreatedAt = now
        , payrollResultEntityUpdatedAt = now
        }
  key <- liftIO $ runSqlPool (P.insert entity) pool
  return $ QuerySuccess PayrollResult
    { prId = keyToInt key
    , prTenantId = tenantId
    , prPeriod = period
    , prEmployeeId = employeeId
    , prGross = gross
    , prDeductions = deductions
    , prNet = net
    , prIncomeTax = incomeTax
    , prSocialTax = socialTax
    , prAdvance = advance
    , prBonus = bonus
    , prVacationPay = vacationPay
    , prSickPay = sickPay
    , prTotalToPay = totalToPay
    , prCurrency = currency
    , prVersion = 1
    , prCreatedBy = Just createdBy
    , prCreatedAt = now
    , prUpdatedAt = now
    }

-- | Get payroll results for a tenant in a given period
getPayrollByPeriod :: ConnectionPool -> Int64 -> Day -> IO (QueryResult [PayrollResult])
getPayrollByPeriod pool tenantId period = do
  entities <- liftIO $ runSqlPool
    (select $ do
      pr <- from $ table @PayrollResultEntity
      where_ $ pr ^. PayrollResultEntityTenantId ==. val tenantId
        &&. pr ^. PayrollResultEntityPeriod ==. val period
      orderBy [asc $ pr ^. PayrollResultEntityEmployeeId]
      return pr)
    pool
  return $ QuerySuccess $ map payrollResultFromEntity entities

-- | Get payroll results for a specific employee
getPayrollByEmployee :: ConnectionPool -> Int64 -> Int64 -> IO (QueryResult [PayrollResult])
getPayrollByEmployee pool tenantId employeeId = do
  entities <- liftIO $ runSqlPool
    (select $ do
      pr <- from $ table @PayrollResultEntity
      where_ $ pr ^. PayrollResultEntityTenantId ==. val tenantId
        &&. pr ^. PayrollResultEntityEmployeeId ==. val employeeId
      orderBy [desc $ pr ^. PayrollResultEntityPeriod]
      return pr)
    pool
  return $ QuerySuccess $ map payrollResultFromEntity entities

-- | Get a single payroll result by ID
getPayrollById :: ConnectionPool -> Int64 -> IO (QueryResult PayrollResult)
getPayrollById pool pid = do
  result <- liftIO $ runSqlPool
    (selectOne $ do
      pr <- from $ table @PayrollResultEntity
      where_ $ pr ^. PayrollResultEntityId ==. val (payrollResultKey pid)
      return pr)
    pool
  return $ case result of
    Just entity -> QuerySuccess $ payrollResultFromEntity entity
    Nothing -> QueryError "Payroll result not found"
