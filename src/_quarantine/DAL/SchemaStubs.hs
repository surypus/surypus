{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE EmptyDataDecls #-}

module DAL.SchemaStubs where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

-- | Migrate all entities (Phase 1: no-op stub)
migrateAll :: IO ()
migrateAll = return ()

-- EventStore entity (stub)
data EventStoreEntity = EventStoreEntity
  { eventStoreEntityAggregateId      :: !Text
  , eventStoreEntityAggregateType    :: !Text
  , eventStoreEntityEventType        :: !Text
  , eventStoreEntityEventVersion     :: !Int
  , eventStoreEntityEventSchemaVersion :: !Int
  , eventStoreEntityEventData        :: !Text
  , eventStoreEntityEventMetadata    :: !(Maybe Text)
  , eventStoreEntitySequenceNumber   :: !Int
  , eventStoreEntityOccurredAt       :: !UTCTime
  , eventStoreEntityCreatedAt        :: !UTCTime
  } deriving (Show, Eq, Generic, Read)

instance FromJSON EventStoreEntity
instance ToJSON EventStoreEntity

-- EventSnapshot entity (stub)
data EventSnapshotEntity = EventSnapshotEntity
  { eventSnapshotEntitySnapshotAggregateId   :: !Text
  , eventSnapshotEntitySnapshotAggregateType :: !Text
  , eventSnapshotEntitySnapshotVersion       :: !Int
  , eventSnapshotEntitySnapshotData          :: !Text
  , eventSnapshotEntityCreatedAt             :: !UTCTime
  } deriving (Show, Eq, Generic, Read)

instance FromJSON EventSnapshotEntity
instance ToJSON EventSnapshotEntity

-- AccountingEvent entity (stub)
data AccountingEventEntity = AccountingEventEntity
  { accountingEventEntityEventId       :: !Text
  , accountingEventEntityAggregateId   :: !Text
  , accountingEventEntityAggregateType :: !Text
  , accountingEventEntityEventType     :: !Text
  , accountingEventEntityEventVersion  :: !Int
  , accountingEventEntityEventData     :: !Text
  , accountingEventEntityMetadata      :: !(Maybe Text)
  , accountingEventEntitySequenceNumber :: !Int
  , accountingEventEntityCreatedAt     :: !UTCTime
  } deriving (Show, Eq, Generic, Read)

instance FromJSON AccountingEventEntity
instance ToJSON AccountingEventEntity

-- AuditLog entity (stub)
data AuditLogEntity = AuditLogEntity
  { auditLogEntityUserId    :: !Int64
  , auditLogEntityAction    :: !Text
  , auditLogEntityEntity    :: !Text
  , auditLogEntityId        :: !(Maybe Text)
  , auditLogEntityMetadata  :: !(Maybe Text)
  , auditLogEntityCreatedAt :: !UTCTime
  } deriving (Show, Eq, Generic, Read)

instance FromJSON AuditLogEntity
instance ToJSON AuditLogEntity
