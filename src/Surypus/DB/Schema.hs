{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Surypus.DB.Schema — Core Persistent entity schema
-- Re-exports existing DAL.Schema entities and adds new ones.
-- Provides migration utilities for the core data layer.
module Surypus.DB.Schema
  ( module DAL.Schema
  , module Surypus.DB.Schema
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime)
import Database.Persist.Sql (SqlBackend, runMigration, runSqlConn)
import Database.Persist.TH

-- Re-export existing DAL schema entities
import DAL.Schema hiding (CurrencyEntity(..))

-- | New core entity: Audit trail entry
share [mkPersist sqlSettings, mkMigrate "migrateCore"] [persistLowerCase|
AuditEntry sql=audit_entry
  entityType Text
  entityId Int64
  action Text
  userId Int64 Maybe
  oldValue Text Maybe
  newValue Text Maybe
  createdAt UTCTime default=CURRENT_TIMESTAMP
  deriving Show Eq

TaxRateOverride sql=tax_rate_override
  taxId Int64
  name Text
  rate Double
  effectiveFrom Day
  effectiveTo Day Maybe
  createdAt UTCTime default=CURRENT_TIMESTAMP
  deriving Show Eq

PaymentEntity sql=payment
  billId Int64
  amount Double
  date UTCTime
  payStatus Int
  method Text
  deriving Show Eq

AccPlanEntity sql=acc_plan
  code Text
  name Text
  accType Int
  deriving Show Eq

SalaryEntity sql=salary
  employeeId Int64
  amount Double
  date UTCTime
  period Day
  deriving Show Eq

UserEntity sql=user
  username Text
  passwordHash Text
  personId Int64 Maybe
  status Text
  tenantId Int64
  deriving Show Eq

ReportTemplateEntity sql=report_template
  code Text
  name Text
  reportType Int
  content Text
  format Text
  deriving Show Eq

CurrencyEntity sql=currency
  code Text
  name Text
  deriving Show Eq

StockEntity sql=stock
  goodsId Int64
  locationId Int64
  qtty Double
  deriving Show Eq

StockMovementEntity sql=stock_movement
  goodsId Int64
  warehouseId Int64
  stockType Text
  qty Double
  createdAt UTCTime default=CURRENT_TIMESTAMP
  deriving Show Eq
|]

-- | Run all migrations (core + legacy)
runMigrations :: SqlBackend -> IO ()
runMigrations backend = do
  runSqlConn (runMigration migrateCore) backend
