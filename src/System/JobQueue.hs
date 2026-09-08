{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric #-}
module System.JobQueue where
 
import Control.Concurrent (forkIO, ThreadId, threadDelay)
import Control.Monad (forever, void)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Aeson (Value, encode, ToJSON, FromJSON)
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Char8 as BSC
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BSL
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import GHC.Generics (Generic)
import Data.Time.Clock (UTCTime, getCurrentTime)
import Database.Redis
import qualified Database.Redis as R
import Control.Exception (try, SomeException)
 
-- | Job queue system using Redis for background processing
data JobQueue = JobQueue
  { redisConfig :: ConnectInfo,
    queuePrefix :: Text,
    queueWorkerCount :: Int
  }
 
data Job = Job
  { jobId :: Text,
    jobType :: Text,
    jobPayload :: Value,
    jobCreatedAt :: UTCTime,
    jobAttempts :: Int
  }
  deriving (Show, Generic)

instance ToJSON Job
instance FromJSON Job
 
-- | Create a new job queue with Redis configuration
initJobQueue :: ConnectInfo -> Text -> Int -> IO JobQueue
initJobQueue config prefix workers = do
  -- Test connection
  conn <- checkedConnect config
  void $ runRedis conn $ ping
  return $ JobQueue config prefix workers
 
-- | Enqueue a job to Redis queue
enqueueJob :: JobQueue -> Job -> IO ()
enqueueJob (JobQueue config prefix _) job = do
  conn <- checkedConnect config
  let queueName = TE.encodeUtf8 (prefix <> ":jobs")
      jobValue = encode job
  runRedis conn $ lpush queueName [toStrict jobValue]
  return ()
 
-- | Dequeue a job from Redis queue (blocking with timeout)
dequeueJob :: JobQueue -> IO (Maybe Job)
dequeueJob (JobQueue config prefix _) = do
  conn <- checkedConnect config
  let queueName = TE.encodeUtf8 (prefix <> ":jobs")
      timeout = 0  -- 0 means block indefinitely
  result :: Either R.Reply (Maybe (BS.ByteString, BS.ByteString)) <- runRedis conn $ brpop [queueName] timeout
  case result of
    Left _ -> return Nothing
    Right Nothing -> return Nothing
    Right (Just (_, value)) -> 
      case Aeson.decode (fromStrict value) of
        Just job -> return (Just job)
        Nothing -> do
          -- Log error but continue
          putStrLn $ "Failed to decode job from Redis: " <> BSC.unpack value
          return Nothing
 
-- | Worker loop for processing jobs from Redis
workerLoop :: JobQueue -> (Job -> IO ()) -> IO ()
workerLoop queue processor = forever $ do
  mbJob <- dequeueJob queue
  case mbJob of
    Nothing -> threadDelay 1000000 -- Wait 1 second if error
    Just job -> do
      result <- try (processor job) :: IO (Either SomeException ())
      case result of
        Left exc -> do
          -- Job failed, retry with exponential backoff (max 3 attempts)
            if jobAttempts job < 3
              then do
                putStrLn $ "Job failed, retrying: " <> T.unpack (jobId job) <> " error: " <> show exc
                let retryJob' = retryJob job
                threadDelay (2 ^ (jobAttempts job) * 1000000) -- Exponential backoff
                enqueueJob queue retryJob'
              else do
                putStrLn $ "Job failed permanently after 3 attempts: " <> T.unpack (jobId job)
        Right _ -> return ()

-- | Create a retry job with incremented attempt count
retryJob :: Job -> Job
retryJob job = job { jobAttempts = jobAttempts job + 1 }
 
-- | Start worker pool
startWorkers :: JobQueue -> Int -> (Job -> IO ()) -> IO [ThreadId]
startWorkers queue count processor = mapM (\_ -> forkIO $ workerLoop queue processor) [1 .. count]
 
-- | Default job processor (can be overridden)
defaultJobProcessor :: Job -> IO ()
defaultJobProcessor job = do
  putStrLn $ "Processing job: " <> T.unpack (jobId job) <> " of type: " <> T.unpack (jobType job)
  -- In a real implementation, this would process the job payload
  return ()
 
-- | Helper to get strict ByteString from Lazy ByteString
toStrict :: BSL.ByteString -> BS.ByteString
toStrict = BSL.toStrict
 
-- | Helper to get Lazy ByteString from Strict ByteString
fromStrict :: BS.ByteString -> BSL.ByteString
fromStrict = BSL.fromStrict
