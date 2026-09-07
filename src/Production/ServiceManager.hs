{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | ServiceManager coordinates daemonized jobs and Cron tasks.
module Production.ServiceManager
  ( runDaemon,
    runJobQueueOnce,
    runCronOnce,
    daemonTickDelay
  ) where

import Control.Concurrent (forkIO, threadDelay)
import Control.Exception (SomeException, try)
import Control.Monad (forever, void)
import Data.Time.Clock (getCurrentTime)
-- | Stub type for Pool
type Pool = ()

daemonTickDelay :: Int
daemonTickDelay = 5 * 1000000 -- 5 seconds

runJobQueueOnce :: Pool -> IO ()
runJobQueueOnce _pool = do
  now <- getCurrentTime
  putStrLn $ "Job queue sweep at " <> show now
  putStrLn "Job queue idle"

runCronOnce :: Pool -> IO ()
runCronOnce _pool = do
  now <- getCurrentTime
  putStrLn $ "Cron tick at " <> show now
  putStrLn "Cron idle"

-- | Run both job queue and cron loops in parallel.
runDaemon :: Pool -> IO ()
runDaemon pool = do
  putStrLn "Daemon: starting job queue and cron loops"
  void . forkIO . forever $ tryRun (runJobQueueOnce pool)
  void . forkIO . forever $ tryRun (runCronOnce pool)
  forever $ threadDelay daemonTickDelay

tryRun :: IO () -> IO ()
tryRun action = do
  result <- try action
  case result of
    Left (err :: SomeException) -> putStrLn $ "Daemon tick failed: " <> show err
    Right () -> pure ()
  threadDelay daemonTickDelay
