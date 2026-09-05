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
import DAL.Schema

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
|]

-- | Run all migrations (core + legacy)
runMigrations :: SqlBackend -> IO ()
runMigrations backend = do
  runSqlConn (runMigration migrateCore) backend
