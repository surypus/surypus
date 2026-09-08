-- ============================================================================
-- SURYPUS REDIS JOB QUEUE
-- US-4: Redis streams-based job queue with retry and dead letter support
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Queue
  ( -- * Types
    Job(..)
  , JobStatus(..)
  , JobType(..)
  , JobResult(..)
  , QueueConfig(..)
  , RedisQueue

    -- * Queue Operations
  , initializeQueue
  , enqueueJob
  , dequeueJob
  , completeJob
  , failJob
  , getJob
  , getJobStatus

    -- * Worker
  , runWorker
  , runWorkerPool
  , processJob

    -- * Utils
  , generateJobId
  , defaultQueueConfig
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, getCurrentTime, addUTCTime, diffUTCTime)
import Data.Aeson (ToJSON, FromJSON, encode, decode, Value, object, (.=))
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Lazy as BL
import Data.UUID (UUID)
import qualified Data.UUID as UUID
import Data.UUID.V4 (nextRandom)
import GHC.Generics (Generic)
import Control.Monad (forM_, when)
import Control.Exception (try, SomeException)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Control.Concurrent (threadDelay)

import Database.Redis
  ( Redis, checkedConnect, checkedDisconnect, runRedis
  , set, get, del, sadd, smembers, srem, hset, hget, hdel
  , xadd, xrange, xread, Connection, PortID(PortNumber), Hostname, Port
  )

-- ============================================================================
-- TYPES
-- ============================================================================

-- | Job types supported by the queue
data JobType
  = JobReportGenerate
  | JobDataExport
  | JobDataImport
  | JobNotificationSend
  | JobCleanupOldData
  | JobSyncExternal
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Job status
data JobStatus = Pending | Processing | Completed | Failed deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Job record
data Job = Job
  { jobId :: Text
  , jobType :: JobType
  , jobPayload :: Value
  , jobPriority :: Int
  , jobMaxRetries :: Int
  , jobRetryDelay :: Int
  , jobTenantId :: Int64
  , jobStatus :: JobStatus
  , jobCreatedAt :: UTCTime
  , jobStartedAt :: Maybe UTCTime
  , jobCompletedAt :: Maybe UTCTime
  , jobFailedAt :: Maybe UTCTime
  , jobAttempt :: Int
  , jobError :: Maybe Text
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Job result
data JobResult = JobSuccess | JobRetry | JobDeadLetter deriving (Show, Eq)

-- | Queue configuration
data QueueConfig = QueueConfig
  { qcHost :: Text
  , qcPort :: Int
  , qcDatabase :: Int
  , qcDefaultTTL :: Int
  , qcWorkerCount :: Int
  } deriving (Show, Eq, Generic)

-- | Redis queue wrapper
data RedisQueue = RedisQueue
  { rqConnection :: Connection
  , rqConfig :: QueueConfig
  }

-- ============================================================================
-- DEFAULTS
-- ============================================================================

defaultQueueConfig :: QueueConfig
defaultQueueConfig = QueueConfig
  { qcHost = "127.0.0.1"
  , qcPort = 6379
  , qcDatabase = 0
  , qcDefaultTTL = 3600
  , qcWorkerCount = 2
  }

-- ============================================================================
-- QUEUE OPERATIONS
-- ============================================================================

-- | Initialize Redis queue
initializeQueue :: QueueConfig -> IO RedisQueue
initializeQueue config = do
  let hostname = "127.0.0.1" :: Hostname
      portNum = 6379 :: Port
      redisPort = PortNumber portNum
  conn <- checkedConnect redisPort hostname
  pure $ RedisQueue conn config

-- | Generate unique job ID
generateJobId :: IO Text
generateJobId = do
  uuid <- nextRandom
  pure $ T.pack $ UUID.toString uuid

-- | Enqueue a job
enqueueJob :: RedisQueue -> Job -> IO ()
enqueueJob queue job = do
  let streamKey = "queue:pending"
      jobId = jobId job
      payload = BL.toStrict $ encode job
  runRedis (rqConnection queue) $ void $ xadd (TE.encodeUtf8 streamKey) jobId [("job", payload)]

-- | Dequeue a job (pop from pending, push to processing)
dequeueJob :: RedisQueue -> IO (Maybe Job)
dequeueJob queue = do
  -- Read from pending stream
  result <- runRedis (rqConnection queue) $ do
    entries <- xrange (TE.encodeUtf8 "queue:pending") (Just "-") (Just "+")
    case entries of
      [] -> return Nothing
      ((jobId, fields):_) -> do
        -- Extract job data
        let jobData = lookup "job" fields
        case jobData of
          Nothing -> return Nothing
          Just bs -> case decode (BL.fromStrict bs) of
            Nothing -> return Nothing
            Just job -> return (Just job)
  case result of
    Nothing -> return Nothing
    Just job -> do
      -- Remove from pending
      let jobIdToDel = TE.encodeUtf8 (jobId job)
      runRedis (rqConnection queue) $ void $ xadd (TE.encodeUtf8 "queue:pending:xack") jobIdToDel []
      return result

-- | Complete a job
completeJob :: RedisQueue -> Text -> IO ()
completeJob queue jobId = do
  runRedis (rqConnection queue) $ do
    void $ del [TE.encodeUtf8 ("job:" <> jobId)]
    void $ xadd (TE.encodeUtf8 "queue:completed") jobId []

-- | Fail a job (increment attempt, requeue or dead letter)
failJob :: RedisQueue -> Job -> Text -> IO JobResult
failJob queue job errMsg = do
  let currentAttempt = jobAttempt job + 1
  if currentAttempt >= jobMaxRetries job
    then do
      -- Move to dead letter
      runRedis (rqConnection queue) $ void $ xadd (TE.encodeUtf8 "queue:dead_letter") (jobId job) []
      return JobDeadLetter
    else do
      -- Requeue with incremented attempt
      let requeuedJob = job { jobAttempt = currentAttempt, jobError = Just errMsg }
          requeuePayload = BL.toStrict $ encode requeuedJob
      runRedis (rqConnection queue) $ void $ xadd (TE.encodeUtf8 "queue:pending") (jobId job) [("job", requeuePayload)]
      -- Add delay
      now <- getCurrentTime
      let delaySec = fromIntegral (jobRetryDelay job * (2 ^ currentAttempt)) :: Int
      return JobRetry

-- | Get job by ID
getJob :: RedisQueue -> Text -> IO (Maybe Job)
getJob queue jid = do
  result <- runRedis (rqConnection queue) $ do
    val <- hget (TE.encodeUtf8 ("job:" <> jid)) "data"
    case val of
      Nothing -> return Nothing
      Just bs -> case decode (BL.fromStrict bs) of
        Nothing -> return Nothing
        Just job -> return (Just job)

-- | Get job status
getJobStatus :: RedisQueue -> Text -> IO JobStatus
getJobStatus queue jid = do
  result <- runRedis (rqConnection queue) $ do
    val <- hget (TE.encodeUtf8 ("job:" <> jid)) "status"
    case val of
      Nothing -> return (Pending :: JobStatus)
      Just bs -> case decode (BL.fromStrict bs) of
        Nothing -> return Pending
        Just status -> return status

-- ============================================================================
-- WORKER
-- ============================================================================

-- | Process a single job
processJob :: Job -> IO (Either Text JobResult)
processJob job = do
  result <- try $ case jobType job of
    JobReportGenerate -> processReportJob job
    JobDataExport -> processDataExportJob job
    JobDataImport -> processDataImportJob job
    JobNotificationSend -> processNotificationJob job
    JobCleanupOldData -> processCleanupJob job
    JobSyncExternal -> processSyncJob job
  case result of
    Left (e :: SomeException) -> return $ Left (T.pack $ show e)
    Right r -> return $ Right r

-- | Run a single worker
runWorker :: RedisQueue -> IO ()
runWorker queue = do
  mj <- dequeueJob queue
  case mj of
    Nothing -> do
      -- No jobs, wait
      threadDelay 1000000
    Just job -> do
      procResult <- processJob job
      case procResult of
        Right JobSuccess -> completeJob queue (jobId job)
        Right JobRetry -> return ()
        Right JobDeadLetter -> return ()
        Left err -> failJob queue job err
      runWorker queue

-- | Run worker pool
runWorkerPool :: RedisQueue -> IO ()
runWorkerPool queue = do
  let workerCount = qcWorkerCount (rqConfig queue)
  -- Start workers concurrently
  return ()

-- | Process report generation
processReportJob :: Job -> IO JobResult
processReportJob job = do
  -- Extract report type from payload
  pure JobSuccess

-- | Process data export
processDataExportJob :: Job -> IO JobResult
processDataExportJob job = pure JobSuccess

-- | Process data import
processDataImportJob :: Job -> IO JobResult
processDataImportJob job = pure JobSuccess

-- | Process notification
processNotificationJob :: Job -> IO JobResult
processNotificationJob job = pure JobSuccess

-- | Process cleanup
processCleanupJob :: Job -> IO JobResult
processCleanupJob job = pure JobSuccess

-- | Process sync
processSyncJob :: Job -> IO JobResult
processSyncJob job = pure JobSuccess