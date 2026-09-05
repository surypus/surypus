{-# LANGUAGE ScopedTypeVariables #-}
module System.Retry where

import Control.Concurrent (threadDelay)
import Control.Exception (SomeException, try)
import Data.Time.Clock (UTCTime, getCurrentTime)
import System.Random (randomRIO)

-- | Retry strategies
data RetryStrategy
  = FixedDelay Int -- Fixed delay in microseconds
  | ExponentialBackoff -- Exponential backoff
  | LinearBackoff Int -- Linear increase
  | Jitter -- Random jitter
  deriving (Show, Eq)

-- | Retry configuration
data RetryConfig = RetryConfig
  { maxAttempts :: Int,
    baseDelay :: Int,
    maxDelay :: Int,
    strategy :: RetryStrategy
  }

-- | Retry result
data RetryResult a
  = Success a UTCTime
  | Failure [SomeException] UTCTime
  deriving (Show)

-- | Execute with retry logic
withRetries :: RetryConfig -> IO a -> IO (RetryResult a)
withRetries config action = go 0 []
  where
    maxAttemptsNum = maxAttempts config
    baseDelayNum = baseDelay config
    maxDelayNum = maxDelay config
    strategyVal = strategy config

    go attempt errs
      | attempt >= maxAttemptsNum =
          Failure errs <$> getCurrentTime
      | otherwise = do
          result <- try action
          case result of
            Right val -> Success val <$> getCurrentTime
            Left (err :: SomeException) -> do
              delay <- calculateDelay attempt
              threadDelay delay
              go (attempt + 1) (err : errs)

    calculateDelay attempt = do
      case strategyVal of
        FixedDelay d -> return d
        ExponentialBackoff ->
          return $ min maxDelayNum (baseDelayNum * (2 ^ attempt))
        LinearBackoff step ->
          return $ min maxDelayNum (baseDelayNum + step * attempt)
        Jitter -> do
          let baseVal = min maxDelayNum (baseDelayNum * (attempt + 1))
          randomRIO (baseVal, baseVal * 3 `div` 2)

-- | Retry with specific delays
withRetriesDelays :: [Int] -> IO a -> IO (Either SomeException a)
withRetriesDelays delays action = go delays
  where
    go [] = do
      result <- try action
      case result of
        Right val -> return $ Right val
        Left (err :: SomeException) -> return $ Left err
    go (d : ds) = do
      result <- try action
      case result of
        Right val -> return $ Right val
        Left (err :: SomeException) -> do
          threadDelay d
          go ds

-- | Retry until success or timeout
untilSuccessWithTimeout :: Int -> Int -> IO a -> IO (Either String a)
untilSuccessWithTimeout attempts delayMicros action = go attempts
  where
    go 0 = return $ Left "max attempts exceeded"
    go n = do
      result <- try action
      case result of
        Right val -> return $ Right val
        Left (_ :: SomeException) -> do
          threadDelay delayMicros
          go (n - 1)
