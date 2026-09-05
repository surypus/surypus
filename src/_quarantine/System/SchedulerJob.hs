{-# LANGUAGE OverloadedStrings #-}
module System.SchedulerJob where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Data.Int (Int64)
import Data.Time.Calendar (Day, addDays)
import Data.Time.Clock (UTCTime, addUTCTime, getCurrentTime, utctDay)
import Data.Text (Text)
import qualified Data.Text as T
import System.HealthCheck (HealthResult)
import System.JobQueue (JobQueue)
import System.Random (randomIO)

-- | Job types
data JobType
  = HealthCheckJob
  | MetricsExportJob
  | WorkflowJob Text
  | NotificationJob
  | CacheCleanupJob
  | AuditFlushJob
  deriving (Show, Eq)

-- | Job execution result
data JobResult
  = JobSuccess UTCTime
  | JobRetry UTCTime
  | JobFailure Text UTCTime
  deriving (Show, Eq)

-- | Scheduled job
data ScheduledJob = ScheduledJob
  { jobId :: Text,
    jobType :: JobType,
    jobQueue :: JobQueue,
    jobSchedule :: JobSchedule,
    jobStatus :: TVar JobStatus,
    jobRetries :: Int,
    jobMaxRetries :: Int
  }

-- | Job schedule
data JobSchedule
  = Once UTCTime
  | Recurring (Day -> Bool)
  | Interval Int64

instance Show JobSchedule where
  show (Once t) = "Once " ++ show t
  show (Recurring _) = "Recurring <fn>"
  show (Interval n) = "Interval " ++ show n

instance Eq JobSchedule where
  Once t1 == Once t2 = t1 == t2
  Recurring _ == Recurring _ = True
  Interval n1 == Interval n2 = n1 == n2
  _ == _ = False

-- | Job status
data JobStatus
  = Pending
  | Scheduled UTCTime
  | Running UTCTime
  | Completed UTCTime
  | Failed Text UTCTime
  | Cancelled
  deriving (Show, Eq)

-- | Initialize job scheduler
initJobScheduler :: IO ()
initJobScheduler = do
  -- Start background scheduler
  return ()

-- | Schedule health check job
scheduleHealthCheck :: JobQueue -> UTCTime -> IO Text
scheduleHealthCheck queue time = do
  jobId <- generateJobId
  statusVar <- newTVarIO Pending
  let job =
        ScheduledJob
          { jobId = jobId,
            jobType = HealthCheckJob,
            jobQueue = queue,
            jobSchedule = Once time,
            jobStatus = statusVar,
            jobRetries = 0,
            jobMaxRetries = 3
          }
  enqueueJob queue job
  return jobId

-- | Schedule metrics export
scheduleMetricsExport :: JobQueue -> UTCTime -> Int64 -> IO Text
scheduleMetricsExport queue time intervalSec = do
  jobId <- generateJobId
  statusVar <- newTVarIO Pending
  let recurring = Recurring (\_ -> True) -- Every day
      job =
        ScheduledJob
          { jobId = jobId,
            jobType = MetricsExportJob,
            jobQueue = queue,
            jobSchedule = recurring,
            jobStatus = statusVar,
            jobRetries = 0,
            jobMaxRetries = 5
          }
  enqueueJob queue job
  return jobId

-- | Schedule workflow job
scheduleWorkflowJob :: JobQueue -> Text -> UTCTime -> IO Text
scheduleWorkflowJob queue workflowId time = do
  jobId <- generateJobId
  statusVar <- newTVarIO Pending
  let job =
        ScheduledJob
          { jobId = jobId,
            jobType = WorkflowJob workflowId,
            jobQueue = queue,
            jobSchedule = Once time,
            jobStatus = statusVar,
            jobRetries = 0,
            jobMaxRetries = 2
          }
  enqueueJob queue job
  return jobId

-- | Execute job
executeJob :: ScheduledJob -> IO JobResult
executeJob job = do
  now <- getCurrentTime
  result <- executeJobAction (jobType job)
  case result of
    JobSuccess _ -> do
      atomically $ writeTVar (jobStatus job) (Completed now)
      return $ JobSuccess now
    JobRetry _ -> do
      let retries = jobRetries job + 1
      atomically $ writeTVar (jobStatus job) (Failed "retry" now)
      if retries < jobMaxRetries job
        then do
          nextTime <- calculateRetryTime retries
          return $ JobRetry nextTime
        else return $ JobFailure "max retries exceeded" now
    JobFailure err _ -> do
      atomically $ writeTVar (jobStatus job) (Failed err now)
      return $ JobFailure err now
  where
    executeJobAction HealthCheckJob = JobSuccess <$> getCurrentTime
    executeJobAction MetricsExportJob = JobSuccess <$> getCurrentTime
    executeJobAction (WorkflowJob wid) = JobSuccess <$> getCurrentTime
    executeJobAction NotificationJob = JobSuccess <$> getCurrentTime
    executeJobAction CacheCleanupJob = JobSuccess <$> getCurrentTime
    executeJobAction AuditFlushJob = JobSuccess <$> getCurrentTime

    calculateRetryTime retries = addUTCTime (fromIntegral (retries * 60)) <$> getCurrentTime

-- | Cancel job
cancelJob :: ScheduledJob -> IO ()
cancelJob job = atomically $ do
  status <- readTVar (jobStatus job)
  case status of
    Pending -> writeTVar (jobStatus job) Cancelled
    Scheduled _ -> writeTVar (jobStatus job) Cancelled
    Running _ -> writeTVar (jobStatus job) Cancelled
    _ -> return ()

-- | Generate job ID
generateJobId :: IO Text
generateJobId = T.pack . show <$> (randomIO :: IO Int)

-- | Enqueue job
enqueueJob :: JobQueue -> ScheduledJob -> IO ()
enqueueJob _ _ = return ()
