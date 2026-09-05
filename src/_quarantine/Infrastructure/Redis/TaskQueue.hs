-- | Redis Task Queue for background report processing
-- Implements Phase 3-4: Redis Task Queue - Фоновая обработка отчетов
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveAnyClass #-}

module Infrastructure.Redis.TaskQueue
  ( Task(..)
  , TaskStatus(..)
  , TaskQueue(..)
  , mkTaskQueue
  , enqueueTask
  , dequeueTask
  , getTaskStatus
  , updateTaskStatus
  , startWorker
  , ReportTask(..)
  ) where

import Data.Aeson (ToJSON, FromJSON, Value, encode, decode)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8, decodeUtf8)
import Data.Time (UTCTime, getCurrentTime)
import Data.UUID (UUID)
import qualified Data.UUID.V4 as UUID
import GHC.Generics (Generic)
import qualified Database.Redis as R
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LBS
import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (forever, void)
import Control.Exception (catch, SomeException)
import Data.Maybe (fromMaybe)

-- | Task status enumeration
data TaskStatus = Pending | Processing | Completed | Failed
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Generic task data structure
data Task = Task
  { taskId :: UUID
  , taskType :: Text
  , taskPayload :: Value
  , taskStatus :: TaskStatus
  , taskCreatedAt :: UTCTime
  , taskStartedAt :: Maybe UTCTime
  , taskCompletedAt :: Maybe UTCTime
  , taskError :: Maybe Text
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Report-specific task payload
data ReportTask = ReportTask
  { rtReportId :: UUID
  , rtReportType :: Text
  , rtParameters :: Value
  , rtTenantId :: Text
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Task queue configuration
data TaskQueue = TaskQueue
  { tqRedisConn :: R.Connection
  , tqQueueName :: Text
  , tqWorkerCount :: Int
  }

-- | Create a new task queue
mkTaskQueue :: R.Connection -> Text -> Int -> TaskQueue
mkTaskQueue conn queueName workerCount =
  TaskQueue
    { tqRedisConn = conn
    , tqQueueName = queueName
    , tqWorkerCount = workerCount
    }

-- | Serialize task to ByteString
taskToBytes :: Task -> Either String ByteString
taskToBytes task = Right $ LBS.toStrict (encode task)

-- | Deserialize task from ByteString
taskFromBytes :: ByteString -> Either String Task
taskFromBytes bs = 
  case decode (LBS.fromStrict bs) of
    Just task -> Right task
    Nothing -> Left "Failed to parse task"

-- | Enqueue a task for background processing
enqueueTask :: TaskQueue -> Text -> Value -> IO (Either Text UUID)
enqueueTask queue taskType payload = do
  taskId <- UUID.nextRandom
  timestamp <- getCurrentTime
  let task = Task
        { taskId = taskId
        , taskType = taskType
        , taskPayload = payload
        , taskStatus = Pending
        , taskCreatedAt = timestamp
        , taskStartedAt = Nothing
        , taskCompletedAt = Nothing
        , taskError = Nothing
        }
  case taskToBytes task of
    Left err -> pure $ Left $ T.pack err
    Right taskBytes -> do
      let queueKey = encodeUtf8 $ tqQueueName queue <> ":pending"
      let taskKey = encodeUtf8 $ "task:" <> T.pack (show taskId)
      result <- R.runRedis (tqRedisConn queue) $ do
        _ <- R.rpush queueKey [taskBytes]
        R.set taskKey taskBytes
      case result of
        Right _ -> pure $ Right taskId
        Left redisErr -> pure $ Left $ T.pack $ show redisErr

-- | Dequeue a task for processing
dequeueTask :: TaskQueue -> IO (Either Text (Maybe Task))
dequeueTask queue = do
  let queueKey = encodeUtf8 $ tqQueueName queue <> ":pending"
  result <- R.runRedis (tqRedisConn queue) $ R.brpop [queueKey] 0
  case result of
    Right (Just (_, taskBytes)) -> 
      case taskFromBytes taskBytes of
        Right task -> pure $ Right $ Just task
        Left err -> pure $ Left $ T.pack err
    Right Nothing -> pure $ Right Nothing
    Left redisErr -> pure $ Left $ T.pack $ show redisErr

-- | Get task status from Redis
getTaskStatus :: TaskQueue -> UUID -> IO (Either Text TaskStatus)
getTaskStatus queue taskId = do
  let taskKey = encodeUtf8 $ "task:" <> T.pack (show taskId)
  result <- R.runRedis (tqRedisConn queue) $ R.get taskKey
  case result of
    Right (Just taskBytes) -> 
      case taskFromBytes taskBytes of
        Right task -> pure $ Right $ taskStatus task
        Left err -> pure $ Left $ T.pack err
    Right Nothing -> pure $ Left "Task not found"
    Left redisErr -> pure $ Left $ T.pack $ show redisErr

-- | Update task status in Redis
updateTaskStatus :: TaskQueue -> UUID -> TaskStatus -> Maybe Text -> IO (Either Text ())
updateTaskStatus queue taskId status errorMsg = do
  let taskKey = encodeUtf8 $ "task:" <> T.pack (show taskId)
  result <- R.runRedis (tqRedisConn queue) $ R.get taskKey
  case result of
    Right (Just taskBytes) -> 
      case taskFromBytes taskBytes of
        Right task -> do
          timestamp <- getCurrentTime
          let updatedTask = task
                { taskStatus = status
                , taskStartedAt = if status == Processing then Just timestamp else taskStartedAt task
                , taskCompletedAt = if status `elem` [Completed, Failed] then Just timestamp else taskCompletedAt task
                , taskError = errorMsg
                }
          case taskToBytes updatedTask of
            Left err -> pure $ Left $ T.pack err
            Right updatedBytes -> do
              setResult <- R.runRedis (tqRedisConn queue) $ R.set taskKey updatedBytes
              case setResult of
                Right _ -> pure $ Right ()
                Left redisErr -> pure $ Left $ T.pack $ show redisErr
        Left err -> pure $ Left $ T.pack err
    Right Nothing -> pure $ Left "Task not found"
    Left redisErr -> pure $ Left $ T.pack $ show redisErr

-- | Start worker processes for the task queue
startWorker :: TaskQueue -> (Task -> IO ()) -> IO ()
startWorker queue taskHandler = do
  mapM_ (\_ -> forkIO $ workerLoop queue taskHandler) [1..tqWorkerCount queue]
  pure ()

-- | Worker loop that continuously processes tasks
workerLoop :: TaskQueue -> (Task -> IO ()) -> IO ()
workerLoop queue taskHandler = forever $ do
  result <- dequeueTask queue
  case result of
    Right (Just task) -> do
      -- Update status to Processing
      _ <- updateTaskStatus queue (taskId task) Processing Nothing
      -- Execute task handler with error handling
      catch (do
        taskHandler task
        _ <- updateTaskStatus queue (taskId task) Completed Nothing
        pure ()) (\(e :: SomeException) -> do
        _ <- updateTaskStatus queue (taskId task) Failed (Just $ T.pack $ show e)
        pure ())
      -- Small delay to prevent tight loop
      threadDelay 100000 -- 100ms
    Right Nothing -> do
      -- No tasks available, wait before retrying
      threadDelay 1000000 -- 1 second
    Left err -> do
      -- Error dequeuing, wait before retrying
      threadDelay 1000000 -- 1 second
