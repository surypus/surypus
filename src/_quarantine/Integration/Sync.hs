-- | Sync module - Data synchronization
module Integration.Sync where

import Data.Int (Int64)
import Data.Time (UTCTime)

-- | SyncSession - Sync session
data SyncSession = SyncSession
  { ssId :: Int64,
    ssDbId :: Int64,
    ssStarted :: UTCTime,
    ssFinished :: Maybe UTCTime,
    ssStatus :: SyncStatus
  }
  deriving (Show, Eq)

data SyncStatus = SSPending | SSInProgress | SSCompleted | SSFailed
  deriving (Show, Eq)

-- | SyncObject - Synced object
data SyncObject = SyncObject
  { soId :: Int64,
    soSessionId :: Int64,
    soObjectType :: Int64,
    soObjectId :: Int64,
    soAction :: SyncAction
  }
  deriving (Show, Eq)

data SyncAction = SACreate | SAUpdate | SADelete
  deriving (Show, Eq)
