-- | Migration module - Database migrations
module Infrastructure.Migration where

import Data.Int (Int64)
import Data.Text (Text)

-- | Migration - Database migration
data Migration = Migration
  { migId :: Int64,
    migVersion :: Text,
    migName :: Text,
    migSQL :: Text,
    migAppliedAt :: Maybe Int64
  }
  deriving (Show, Eq)

-- | MigrationLog - Migration execution log
data MigrationLog = MigrationLog
  { mlId :: Int64,
    mlMigrationId :: Int64,
    mlExecutedAt :: Int64,
    mlSuccess :: Bool,
    mlError :: Maybe Text
  }
  deriving (Show, Eq)
