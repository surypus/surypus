-- | JobQueue module - Background jobs
module Production.JobQueue where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)

-- | Job - Background job
data Job = Job
  { jobId :: Int64,
    jobType :: JobType,
    jobParams :: Text, -- JSON
    jobStatus :: JobStatus,
    jobPriority :: Int,
    jobCreated :: UTCTime,
    jobStarted :: Maybe UTCTime,
    jobFinished :: Maybe UTCTime,
    jobResult :: Maybe Text
  }
  deriving (Show, Eq)

data JobType = JTSync | JTImport | JTExport | JTReport | JTCleanup
  deriving (Show, Eq)

data JobStatus = JSPending | JSRunning | JSCompleted | JSFailed
  deriving (Show, Eq)

-- | JobServer - Job processor
data JobServer = JobServer
  { jsId :: Int64,
    jsName :: Text,
    jsHost :: Text,
    jsPort :: Int,
    jsStatus :: ServerStatus,
    jsFlags :: Int
  }
  deriving (Show, Eq)

data ServerStatus = SSOnline | SSOffline | SSBusy
  deriving (Show, Eq)

-- | Check if job is overdue (running > 1 hour)
isJobOverdue :: Job -> UTCTime -> Bool
isJobOverdue job _now = case jobStarted job of
  Nothing -> False
  Just _st -> jobStatus job == JSRunning
