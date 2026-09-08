{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | PostgreSQL-backed job queue with retry and dead letter support
module DAL.Queue
  ( Job(..)
  , JobStatus(..)
  , JobType(..)
  , JobResult(..)
  , QueueConfig(..)
  , initializeQueue
  , enqueueJob
  , dequeueJob
  , completeJob
  , failJob
  , getJob
  , getJobStatus
  , runWorker
  , runWorkerPool
  , processJob
  , generateJobId
  , defaultQueueConfig
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime, addUTCTime, diffUTCTime)
import Data.Aeson (ToJSON, FromJSON, encode, decode, Value, object, (.=))
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
import DAL.Database (ConnectionPool, runDb)
import Database.Persist.Sql (rawSql, rawExecute, Single(..), PersistValue(..))

-- | Job status
data JobStatus = JobPending | JobProcessing | JobCompleted | JobFailed | JobDeadLetter
  deriving (Show, Eq, Generic, Read)

instance ToJSON JobStatus
instance FromJSON JobStatus

-- | Job type
data JobType
  = BillPosting
  | InventoryReceipt
  | InventoryIssue
  | ReportGeneration
  | DataExport
  | DataImport
  | EmailNotification
  | CustomJob Text
  deriving (Show, Eq, Generic)

instance ToJSON JobType
instance FromJSON JobType

-- | Job result
data JobResult = JobResult
  { jobResultStatus :: !JobStatus
  , jobResultData :: !(Maybe Value)
  , jobResultError :: !(Maybe Text)
  , jobResultCompletedAt :: !(Maybe UTCTime)
  } deriving (Show, Eq, Generic)

instance ToJSON JobResult
instance FromJSON JobResult

-- | Job
data Job = Job
  { jobId :: !Text
  , jobType :: !JobType
  , jobStatus :: !JobStatus
  , jobPayload :: !Value
  , jobPriority :: !Int
  , jobRetryCount :: !Int
  , jobMaxRetries :: !Int
  , jobCreatedAt :: !UTCTime
  , jobScheduledAt :: !(Maybe UTCTime)
  , jobProcessedAt :: !(Maybe UTCTime)
  , jobCompletedAt :: !(Maybe UTCTime)
  , jobError :: !(Maybe Text)
  , jobResult :: !(Maybe JobResult)
  } deriving (Show, Eq, Generic)

instance ToJSON Job
instance FromJSON Job

-- | Queue configuration
data QueueConfig = QueueConfig
  { queueName :: !Text
  , queueMaxRetries :: !Int
  , queueRetryDelayMs :: !Int
  , queueWorkerCount :: !Int
  , queuePollIntervalMs :: !Int
  } deriving (Show, Eq)

-- | Default queue configuration
defaultQueueConfig :: QueueConfig
defaultQueueConfig = QueueConfig
  { queueName = "default"
  , queueMaxRetries = 3
  , queueRetryDelayMs = 1000
  , queueWorkerCount = 4
  , queuePollIntervalMs = 100
  }

-- | Generate a new job ID
generateJobId :: IO Text
generateJobId = do
  uuid <- nextRandom
  return $ T.pack $ UUID.toString uuid

-- | Initialize queue (create table if not exists)
initializeQueue :: ConnectionPool -> QueueConfig -> IO ()
initializeQueue pool config = do
  runDb pool $ rawExecute "CREATE TABLE IF NOT EXISTS job_queue (id UUID PRIMARY KEY, type TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', payload JSONB NOT NULL, priority INT NOT NULL DEFAULT 0, retry_count INT NOT NULL DEFAULT 0, max_retries INT NOT NULL DEFAULT 3, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), scheduled_at TIMESTAMPTZ, processed_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, error TEXT, result JSONB, worker_id TEXT) WITH (fillfactor=70)" []
  runDb pool $ rawExecute "CREATE INDEX IF NOT EXISTS idx_job_queue_status ON job_queue(status)" []
  runDb pool $ rawExecute "CREATE INDEX IF NOT EXISTS idx_job_queue_priority ON job_queue(priority DESC)" []
  runDb pool $ rawExecute "CREATE INDEX IF NOT EXISTS idx_job_queue_scheduled ON job_queue(scheduled_at)" []
  return ()

-- | Enqueue a new job
enqueueJob :: ConnectionPool -> QueueConfig -> JobType -> Value -> Int -> IO Job
enqueueJob pool config jobType payload priority = do
  jobId <- generateJobId
  now <- getCurrentTime
  let job = Job
        { jobId = jobId
        , jobType = jobType
        , jobStatus = JobPending
        , jobPayload = payload
        , jobPriority = priority
        , jobRetryCount = 0
        , jobMaxRetries = queueMaxRetries config
        , jobCreatedAt = now
        , jobScheduledAt = Nothing
        , jobProcessedAt = Nothing
        , jobCompletedAt = Nothing
        , jobError = Nothing
        , jobResult = Nothing
        }
  let sql = "INSERT INTO job_queue (id, type, status, payload, priority, retry_count, max_retries, created_at) \
            \VALUES (?, ?, 'pending', ?::jsonb, ?, 0, ?, ?)"
  runDb pool $ rawExecute sql
    [ PersistText jobId
    , PersistText (jobTypeToText jobType)
    , PersistText (T.pack $ show payload)
    , PersistInt64 (fromIntegral priority)
    , PersistInt64 (fromIntegral $ queueMaxRetries config)
    , PersistUTCTime now
    ]
  return job

-- | Dequeue next available job
dequeueJob :: ConnectionPool -> QueueConfig -> IO (Maybe Job)
dequeueJob pool config = do
  now <- getCurrentTime
  let sql = "UPDATE job_queue SET status = 'processing', processed_at = NOW(), worker_id = ? \
            \WHERE id = (\
            \  SELECT id FROM job_queue \
            \  WHERE status = 'pending' \
            \  AND (scheduled_at IS NULL OR scheduled_at <= ?) \
            \  ORDER BY priority DESC, created_at ASC \
            \  LIMIT 1 \
            \  FOR UPDATE SKIP LOCKED\
            \)\
            \RETURNING id, type, status, payload, priority, retry_count, max_retries, created_at, scheduled_at, processed_at, completed_at, error, result"
  rows <- runDb pool $ rawSql sql [PersistText "worker-1", PersistUTCTime now]
  case rows of
    (Single id : Single typ : Single status : Single payload : Single priority : Single retryCount : Single maxRetries : Single createdAt : Single scheduledAt : Single processedAt : Single completedAt : Single err : Single result : _) -> do
      let mJob = textToJob (T.unpack $ persistToText id) (T.unpack $ persistToText typ) (T.unpack $ persistToText status) (T.unpack $ persistToText payload) (T.unpack $ persistToText priority) (T.unpack $ persistToText retryCount) (T.unpack $ persistToText maxRetries) (T.unpack $ persistToText createdAt) (T.unpack $ persistToText scheduledAt) (T.unpack $ persistToText processedAt) (T.unpack $ persistToText completedAt) (T.unpack $ persistToText err) (T.unpack $ persistToText result)
      return mJob
    _ -> return Nothing

-- | Mark job as completed
completeJob :: ConnectionPool -> Text -> JobResult -> IO ()
completeJob pool jobId result = do
  now <- getCurrentTime
  let sql = "UPDATE job_queue SET status = 'completed', completed_at = ?, result = ?::jsonb WHERE id = ?"
  runDb pool $ rawExecute sql
    [ PersistUTCTime now
    , PersistText (T.pack $ show result)
    , PersistText jobId
    ]

-- | Mark job as failed (with retry)
failJob :: ConnectionPool -> QueueConfig -> Text -> Text -> IO ()
failJob pool config jobId err = do
  let sql = "UPDATE job_queue SET \
            \  status = CASE WHEN retry_count >= max_retries THEN 'dead_letter' ELSE 'pending' END, \
            \  error = ?, \
            \  retry_count = retry_count + 1, \
            \  scheduled_at = NOW() + (? * interval '1 millisecond') \
            \WHERE id = ?"
  runDb pool $ rawExecute sql
    [ PersistText err
    , PersistInt64 (fromIntegral $ queueRetryDelayMs config)
    , PersistText jobId
    ]

-- | Get job by ID
getJob :: ConnectionPool -> Text -> IO (Maybe Job)
getJob pool jobId = do
  let sql = "SELECT id, type, status, payload, priority, retry_count, max_retries, created_at, scheduled_at, processed_at, completed_at, error, result FROM job_queue WHERE id = ?"
  rows <- runDb pool $ rawSql sql [PersistText jobId]
  case rows of
    (Single id : Single typ : Single status : Single payload : Single priority : Single retryCount : Single maxRetries : Single createdAt : Single scheduledAt : Single processedAt : Single completedAt : Single err : Single result : _) -> do
      let mJob = textToJob (T.unpack $ persistToText id) (T.unpack $ persistToText typ) (T.unpack $ persistToText status) (T.unpack $ persistToText payload) (T.unpack $ persistToText priority) (T.unpack $ persistToText retryCount) (T.unpack $ persistToText maxRetries) (T.unpack $ persistToText createdAt) (T.unpack $ persistToText scheduledAt) (T.unpack $ persistToText processedAt) (T.unpack $ persistToText completedAt) (T.unpack $ persistToText err) (T.unpack $ persistToText result)
      return mJob
    _ -> return Nothing

-- | Get job status
getJobStatus :: ConnectionPool -> Text -> IO (Maybe JobStatus)
getJobStatus pool jobId = do
  let sql = "SELECT status FROM job_queue WHERE id = ?"
  rows <- runDb pool $ rawSql sql [PersistText jobId]
  case rows of
    (Single status : _) -> return $ readMaybe $ T.unpack $ T.pack $ show status
    _ -> return Nothing

-- | Run a single worker iteration
runWorker :: ConnectionPool -> QueueConfig -> (Job -> IO JobResult) -> IO ()
runWorker pool config processJobFn = do
  mJob <- dequeueJob pool config
  case mJob of
    Nothing -> threadDelay (queuePollIntervalMs config * 1000)
    Just job -> do
      result <- processJobFn job
      case jobResultStatus result of
        JobCompleted -> completeJob pool (jobId job) result
        JobFailed -> failJob pool config (jobId job) (maybe "Unknown error" id $ jobResultError result)
        _ -> failJob pool config (jobId job) "Invalid result status"

-- | Run a pool of workers
runWorkerPool :: ConnectionPool -> QueueConfig -> (Job -> IO JobResult) -> IO ()
runWorkerPool pool config processJobFn = do
  initializeQueue pool config
  forM_ [1..queueWorkerCount config] $ \_ ->
    runWorker pool config processJobFn

-- | Process a job (placeholder - implement based on job type)
processJob :: ConnectionPool -> Job -> IO JobResult
processJob pool job = do
  result <- try $ case jobType job of
    BillPosting -> processBillPosting pool (jobPayload job)
    InventoryReceipt -> processInventoryReceipt pool (jobPayload job)
    InventoryIssue -> processInventoryIssue pool (jobPayload job)
    ReportGeneration -> processReportGeneration pool (jobPayload job)
    DataExport -> processDataExport pool (jobPayload job)
    DataImport -> processDataImport pool (jobPayload job)
    EmailNotification -> processEmailNotification pool (jobPayload job)
    CustomJob name -> processCustomJob name pool (jobPayload job)
  case result of
    Left (e :: SomeException) -> return $ JobResult JobFailed Nothing (Just $ T.pack $ show e) Nothing
    Right val -> return $ JobResult JobCompleted (Just val) Nothing Nothing

-- | Process bill posting
processBillPosting :: ConnectionPool -> Value -> IO Value
processBillPosting pool payload = do
  return $ object ["status" .= ("posted" :: Text), "payload" .= payload]

-- | Process inventory receipt
processInventoryReceipt :: ConnectionPool -> Value -> IO Value
processInventoryReceipt pool payload = do
  return $ object ["status" .= ("received" :: Text), "payload" .= payload]

-- | Process inventory issue
processInventoryIssue :: ConnectionPool -> Value -> IO Value
processInventoryIssue pool payload = do
  return $ object ["status" .= ("issued" :: Text), "payload" .= payload]

-- | Process report generation
processReportGeneration :: ConnectionPool -> Value -> IO Value
processReportGeneration pool payload = do
  return $ object ["status" .= ("generated" :: Text), "payload" .= payload]

-- | Process data export
processDataExport :: ConnectionPool -> Value -> IO Value
processDataExport pool payload = do
  return $ object ["status" .= ("exported" :: Text), "payload" .= payload]

-- | Process data import
processDataImport :: ConnectionPool -> Value -> IO Value
processDataImport pool payload = do
  return $ object ["status" .= ("imported" :: Text), "payload" .= payload]

-- | Process email notification
processEmailNotification :: ConnectionPool -> Value -> IO Value
processEmailNotification pool payload = do
  return $ object ["status" .= ("sent" :: Text), "payload" .= payload]

-- | Process custom job
processCustomJob :: Text -> ConnectionPool -> Value -> IO Value
processCustomJob name pool payload = do
  return $ object ["status" .= ("completed" :: Text), "name" .= name, "payload" .= payload]

-- | Convert job type to text
jobTypeToText :: JobType -> Text
jobTypeToText BillPosting = "bill_posting"
jobTypeToText InventoryReceipt = "inventory_receipt"
jobTypeToText InventoryIssue = "inventory_issue"
jobTypeToText ReportGeneration = "report_generation"
jobTypeToText DataExport = "data_export"
jobTypeToText DataImport = "data_import"
jobTypeToText EmailNotification = "email_notification"
jobTypeToText (CustomJob name) = name

-- | Parse job type from text
textToJobType :: Text -> JobType
textToJobType "bill_posting" = BillPosting
textToJobType "inventory_receipt" = InventoryReceipt
textToJobType "inventory_issue" = InventoryIssue
textToJobType "report_generation" = ReportGeneration
textToJobType "data_export" = DataExport
textToJobType "data_import" = DataImport
textToJobType "email_notification" = EmailNotification
textToJobType name = CustomJob name

-- | Helper to reconstruct job from text fields
textToJob :: Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Maybe Job
textToJob id' typ status payload priority retryCount maxRetries createdAt scheduledAt processedAt completedAt err result = do
  mPriority <- readMaybe (T.unpack priority)
  mRetryCount <- readMaybe (T.unpack retryCount)
  mMaxRetries <- readMaybe (T.unpack maxRetries)
  mCreatedAt <- readMaybe (T.unpack createdAt)
  mScheduledAt <- if T.null scheduledAt then return Nothing else readMaybe (T.unpack scheduledAt)
  mProcessedAt <- if T.null processedAt then return Nothing else readMaybe (T.unpack processedAt)
  mCompletedAt <- if T.null completedAt then return Nothing else readMaybe (T.unpack completedAt)
  mResult <- if T.null result then return Nothing else readMaybe (T.unpack result)
  return Job
    { jobId = id'
    , jobType = textToJobType typ
    , jobStatus = read (T.unpack status)
    , jobPayload = object ["raw" .= payload]
    , jobPriority = mPriority
    , jobRetryCount = mRetryCount
    , jobMaxRetries = mMaxRetries
    , jobCreatedAt = mCreatedAt
    , jobScheduledAt = mScheduledAt
    , jobProcessedAt = mProcessedAt
    , jobCompletedAt = mCompletedAt
    , jobError = if T.null err then Nothing else Just err
    , jobResult = mResult
    }

-- | Safe readMaybe
readMaybe :: Read a => String -> Maybe a
readMaybe s = case reads s of
  [(x, "")] -> Just x
  _ -> Nothing
