-- | Cron module - Scheduled tasks
module Production.Scheduling.Cron where

import Data.Int (Int64)
import Data.Text (Text)

-- | CronTask - Scheduled task
data CronTask = CronTask
  { ctId :: Int64,
    ctName :: Text,
    ctSchedule :: Text, -- cron expression
    ctCommand :: Text,
    ctEnabled :: Bool,
    ctLastRun :: Maybe Int64,
    ctNextRun :: Maybe Int64
  }
  deriving (Show, Eq)

-- | CronLog - Task execution log
data CronLog = CronLog
  { clId :: Int64,
    clTaskId :: Int64,
    clStarted :: Int64,
    clFinished :: Maybe Int64,
    clStatus :: CronStatus,
    clOutput :: Text
  }
  deriving (Show, Eq)

data CronStatus = CSRunning | CSSuccess | CSFailed
  deriving (Show, Eq)
