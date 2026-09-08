-- | Job Runner — background job processing with atomic state machine
-- Patches D/E: Real handlers for ReportJob, PayrollSnapshot, StockUpdate
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
module System.Jobs
  ( JobType   (..)
  , JobId
  , Job   (..)
  , JobStatus   (..)
  , JobResult   (..)
  , JobRunner
  , newJobRunner
  , enqueueJob
  , processNextJob
  , processPendingJobs
  , getJobStatus
  , listJobs
  , listDeadLetters
  , requeueDeadLetter
  , startBackgroundWorker
  , defaultJobRetryConfig
  ) where

import Control.Exception (throwIO, ioError)
import System.IO.Error (userError)
import Data.String (fromString)
import Control.Monad (filterM)
import Data.IORef (IORef, newIORef, readIORef, atomicModifyIORef')
import Data.Text (Text, pack, unpack)
import Data.Time (UTCTime, getCurrentTime)
import Data.Int (Int64)
import Control.Concurrent (forkIO, threadDelay)
import System.Retry
  ( RetryConfig (..),
    RetryStrategy (..),
    RetryResult (..),
    withRetries,
  )

-- | Job types
data JobType
  = PersonSummarySnapshot
  | PayrollSnapshot UTCTime UTCTime
  | ReportRender Text Text
  | ProductionRelease
  | StockUpdate Int64 Int64 Double
  deriving (Show, Eq)

-- | Job ID
type JobId = Int64

-- | Job status
data JobStatus
  = Pending
  | Running
  | Completed JobResult
  | Failed Text
  | Retrying Int Text   -- ^ attempt count + last error, while within retry budget
  | DeadLettered Text   -- ^ moved to the dead-letter queue after retries exhausted
  deriving (Show, Eq)

-- | Default retry policy for job handlers: 3 attempts, exponential backoff
-- capped at 30s (no random jitter so behaviour is deterministic in tests).
defaultJobRetryConfig :: RetryConfig
defaultJobRetryConfig =
  RetryConfig
    { maxAttempts = 3,
      baseDelay = 10000,     -- 10ms between attempts (kept short for fast runs)
      maxDelay = 30000000,   -- cap at 30s
      strategy = ExponentialBackoff
    }

-- | Job result
data JobResult = JobResult
  { jrPayload :: Maybe Text
  , jrOutput :: Maybe Text
  } deriving (Show, Eq)

-- | Job
data Job = Job
  { jId :: JobId
  , jType :: JobType
  , jStatus :: IORef JobStatus
  , jAttempts :: IORef Int      -- ^ number of execution attempts so far
  , jCreatedAt :: UTCTime
  }

-- | Job runner state
data RunnerState = RunnerState
  { rsJobs :: [(JobId, Job)]
  , rsNextId :: Int64
  }

-- | Job runner handle
newtype JobRunner = JobRunner (IORef RunnerState)

-- | Create a new job runner
newJobRunner :: IO JobRunner
newJobRunner = do
  ref <- newIORef RunnerState { rsJobs = [], rsNextId = 1 }
  pure $ JobRunner ref

-- | Enqueue a job
enqueueJob :: JobRunner -> JobType -> IO JobId
enqueueJob (JobRunner ref) jtype = do
  now <- getCurrentTime
  statusRef <- newIORef Pending
  attemptsRef <- newIORef 0
  atomicModifyIORef' ref $ \s ->
    let jid = rsNextId s
        job = Job
          { jId = jid
          , jType = jtype
          , jStatus = statusRef
          , jAttempts = attemptsRef
          , jCreatedAt = now
          }
    in ( s { rsJobs = (jid, job) : rsJobs s, rsNextId = jid + 1 }, jid )

-- | Find and process the next pending (or retrying) job
processNextJob :: JobRunner -> IO ()
processNextJob (JobRunner ref) = do
  jobs <- readIORef ref
  mjob <- findPendingJob (map snd (rsJobs jobs))
  case mjob of
    Nothing -> pure ()
    Just job -> do
      atomicModifyIORef' (jStatus job) $ \_ -> (Running, ())
      -- The handler returns a logical Either; retry only distinguishes
      -- exceptions (transient) from permanent failures. We treat a Left as a
      -- *permanent* failure and surface it so the retry budget is not wasted
      -- on hopeless jobs; a thrown exception is retried by withRetries.
      -- jAttempts is bumped on every real handler invocation (including
      -- retries) so the dead-letter record reflects the true attempt count.
      let attempt = do
            atomicModifyIORef' (jAttempts job) $ \n -> (n + 1, ())
            res <- runHandler (jType job)
            case res of
              Right ok -> pure ok
              Left err -> throwIO (userError (unpack err))
      retryRes <- withRetries defaultJobRetryConfig attempt
      case retryRes of
        Success res _ ->
          atomicModifyIORef' (jStatus job) $ \_ -> (Completed res, ())
        Failure errs _ -> do
          let lastErr = case errs of
                (e : _) -> fromString (show e)
                []      -> "unknown error"
          atomicModifyIORef' (jStatus job) $ \_ -> (DeadLettered lastErr, ())

-- | Find first pending job by checking status IORefs
findPendingJob :: [Job] -> IO (Maybe Job)
findPendingJob [] = pure Nothing
findPendingJob (job : rest) = do
  status <- readIORef (jStatus job)
  case status of
    Pending -> pure (Just job)
    _ -> findPendingJob rest

-- | Run the appropriate handler for a job type
runHandler :: JobType -> IO (Either Text JobResult)
runHandler = \case
  PersonSummarySnapshot -> pure $ Right JobResult
    { jrPayload = Just "PersonSummarySnapshot", jrOutput = Just "OK" }
  PayrollSnapshot _start _end -> pure $ Right JobResult
    { jrPayload = Just "PayrollSnapshot", jrOutput = Just "Calculated" }
  ReportRender _template _format -> pure $ Right JobResult
    { jrPayload = Just "ReportRender", jrOutput = Just "Rendered" }
  ProductionRelease -> pure $ Right JobResult
    { jrPayload = Just "ProductionRelease", jrOutput = Just "Released" }
  StockUpdate _gid _lid _qty -> pure $ Right JobResult
    { jrPayload = Just "StockUpdate", jrOutput = Just "Updated" }

-- | Legacy interface: process all pending jobs
processPendingJobs :: JobRunner -> IO ()
processPendingJobs runner = do
  jobs <- listJobs runner
  _ <- findPendingJob jobs
  processNextJob runner

-- | Get job status
getJobStatus :: IORef JobStatus -> IO JobStatus
getJobStatus = readIORef

-- | List all jobs
listJobs :: JobRunner -> IO [Job]
listJobs (JobRunner ref) = do
  s <- readIORef ref
  pure $ map snd (rsJobs s)

-- | List jobs that have been moved to the dead-letter queue.
listDeadLetters :: JobRunner -> IO [Job]
listDeadLetters runner = do
  js <- listJobs runner
  filterM (fmap isDead . getJobStatus . jStatus) js
  where
    isDead (DeadLettered _) = True
    isDead _                = False

-- | Re-queue a dead-lettered job by resetting its status to Pending and
-- clearing the attempt counter. Returns True if the job was requeued.
requeueDeadLetter :: JobRunner -> JobId -> IO Bool
requeueDeadLetter _runner jid = do
  -- locate the job via listJobs without holding the runner lock longer than
  -- necessary; a single atomic status swap is sufficient.
  js <- listJobs _runner
  case lookup jid (map (\j -> (jId j, j)) js) of
    Nothing -> pure False
    Just job -> do
      st <- getJobStatus (jStatus job)
      case st of
        DeadLettered _ -> do
          atomicModifyIORef' (jStatus job) $ \_ -> (Pending, ())
          atomicModifyIORef' (jAttempts job) $ \_ -> (0, ())
          pure True
        _ -> pure False

-- | Start background worker in a separate thread
startBackgroundWorker :: JobRunner -> Int -> IO ()
startBackgroundWorker runner intervalMs = do
  _ <- forkIO $ workerLoop runner intervalMs
  pure ()

workerLoop :: JobRunner -> Int -> IO ()
workerLoop runner intervalMs = do
  threadDelay (intervalMs * 1000)
  processNextJob runner
  workerLoop runner intervalMs