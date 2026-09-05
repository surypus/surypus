{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module System.CircuitBreaker
  ( CircuitBreaker(..)
  , CBState(..)
  , CircuitConfig(..)
  , CBMetrics(..)
  , FeatureFlags(..)
  , initCircuitBreaker
  , executeWithCircuitBreaker
  , getCircuitState
  , resetCircuitBreaker
  ) where

import Control.Concurrent.STM (STM, TVar, atomically, newTVarIO, readTVar, readTVarIO, writeTVar)
import Control.Exception (SomeException, try)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)

-- | Circuit states
data CBState
  = CBSClosed {closedThreshold :: Int}
  | CBSOpen {openSince :: UTCTime, openReason :: Text}
  | CBSHalfOpen {halfOpenAttempts :: Int}
  | CBSDisabled
  deriving (Show, Eq)

-- | Circuit configuration
data CircuitConfig = CircuitConfig
  { failureThresholdCount :: Int,
    resetTimeoutSec :: Int,
    halfOpenMaxCalls :: Int,
    failureRateThreshold :: Double,
    successThreshold :: Double
  }

-- | Circuit metrics
data CBMetrics = CBMetrics
  { totalRequests :: Int,
    totalFailures :: Int,
    totalSuccesses :: Int,
    failureRate :: Double,
    lastStateTransition :: UTCTime
  }

-- | Feature flags for parameterizing circuit breaker behavior
data FeatureFlags = FeatureFlags
  { ffTrackMetrics :: Bool,   -- ^ Track metrics when True (default)
    ffTrackHistory :: Bool    -- ^ Track state history when True (default)
  }

-- | Default feature flags (all tracking enabled)
defaultFeatureFlags :: FeatureFlags
defaultFeatureFlags = FeatureFlags
  { ffTrackMetrics = True,
    ffTrackHistory = True
  }

-- | Full-featured circuit breaker with parameterized feature toggles
data CircuitBreaker = CircuitBreaker
  { cbStateVar :: TVar CBState,
    cbFailures :: TVar [UTCTime],
    cbSuccesses :: TVar Int,
    cbConfig :: CircuitConfig,
    cbMetrics :: TVar CBMetrics,
    cbHistory :: TVar [(UTCTime, CBState)],
    cbFeatures :: FeatureFlags
  }

-- | Initialize a circuit breaker with the given config and default feature flags
initCircuitBreaker :: CircuitConfig -> IO CircuitBreaker
initCircuitBreaker config = initCircuitBreakerWithFeatures config defaultFeatureFlags

-- | Initialize a circuit breaker with the given config and feature flags
initCircuitBreakerWithFeatures :: CircuitConfig -> FeatureFlags -> IO CircuitBreaker
initCircuitBreakerWithFeatures config features = do
  stateVar <- newTVarIO (CBSClosed 0)
  failuresVar <- newTVarIO []
  successesVar <- newTVarIO 0
  historyVar <- newTVarIO []
  now <- getCurrentTime
  metricsVar <-
    newTVarIO
      CBMetrics
        { totalRequests = 0,
          totalFailures = 0,
          totalSuccesses = 0,
          failureRate = 0,
          lastStateTransition = now
        }
  return
    CircuitBreaker
      { cbStateVar = stateVar,
        cbFailures = failuresVar,
        cbSuccesses = successesVar,
        cbConfig = config,
        cbMetrics = metricsVar,
        cbHistory = historyVar,
        cbFeatures = features
      }

-- | Execute an action with circuit breaker protection
executeWithCircuitBreaker :: CircuitBreaker -> IO a -> IO (Either Text a)
executeWithCircuitBreaker breaker action = do
  state <- readTVarIO (cbStateVar breaker)
  now <- getCurrentTime

  case state of
    CBSDisabled -> return $ Left "Circuit breaker disabled"
    CBSOpen{openSince=since} ->
      if diffUTCTime now since >= fromIntegral (resetTimeoutSec (cbConfig breaker))
        then do
          atomically $ writeTVar (cbStateVar breaker) (CBSHalfOpen 0)
          executeWithCircuitBreaker breaker action
        else return $ Left "Circuit open"
    CBSClosed{} -> do
      result <- try action
      case result of
        Right val -> do
          atomically $ do
            s <- readTVar (cbSuccesses breaker)
            writeTVar (cbSuccesses breaker) (s + 1)
            if ffTrackMetrics (cbFeatures breaker)
              then updateMetrics breaker now (Right val)
              else pure ()
            if ffTrackHistory (cbFeatures breaker)
              then do
                hist <- readTVar (cbHistory breaker)
                writeTVar (cbHistory breaker) ((now, state) : take 999 hist)
              else pure ()
          return $ Right val
        Left err -> do
          let errText = T.pack $ show (err :: SomeException)
          atomically $ do
            f <- readTVar (cbFailures breaker)
            writeTVar (cbFailures breaker) (f ++ [now])
            if ffTrackMetrics (cbFeatures breaker)
              then updateMetrics breaker now (Left errText)
              else pure ()
            if ffTrackHistory (cbFeatures breaker)
              then do
                hist <- readTVar (cbHistory breaker)
                writeTVar (cbHistory breaker) ((now, state) : take 999 hist)
              else pure ()
            checkFailureThreshold breaker now
          return $ Left errText
    CBSHalfOpen attempts -> do
      if attempts >= halfOpenMaxCalls (cbConfig breaker)
        then return $ Left "Half-open limit reached"
        else do
          atomically $ writeTVar (cbStateVar breaker) (CBSHalfOpen (attempts + 1))
          result <- try action
          case result of
            Right val -> do
              atomically $ do
                writeTVar (cbStateVar breaker) (CBSClosed 0)
                s <- readTVar (cbSuccesses breaker)
                writeTVar (cbSuccesses breaker) (s + 1)
                if ffTrackMetrics (cbFeatures breaker)
                  then updateMetrics breaker now (Right val)
                  else pure ()
                if ffTrackHistory (cbFeatures breaker)
                  then do
                    hist <- readTVar (cbHistory breaker)
                    writeTVar (cbHistory breaker) ((now, CBSClosed 0) : take 999 hist)
                  else pure ()
              return $ Right val
            Left (err :: SomeException) -> do
              let errText = T.pack $ show err
              atomically $ do
                writeTVar (cbStateVar breaker) (CBSOpen now errText)
                f <- readTVar (cbFailures breaker)
                writeTVar (cbFailures breaker) (f ++ [now])
                if ffTrackMetrics (cbFeatures breaker)
                  then updateMetrics breaker now (Left errText)
                  else pure ()
                if ffTrackHistory (cbFeatures breaker)
                  then do
                    hist <- readTVar (cbHistory breaker)
                    writeTVar (cbHistory breaker) ((now, CBSOpen now errText) : take 999 hist)
                  else pure ()
              return $ Left errText
  where
    checkFailureThreshold :: CircuitBreaker -> UTCTime -> STM ()
    checkFailureThreshold breaker' now' = do
      failures <- readTVar (cbFailures breaker')
      let recent =
            filter
              (\t -> diffUTCTime now' t <= fromIntegral (resetTimeoutSec (cbConfig breaker')))
              failures
      if length recent >= failureThresholdCount (cbConfig breaker')
        then writeTVar (cbStateVar breaker') (CBSOpen now' "failure threshold reached")
        else pure ()

    updateMetrics :: CircuitBreaker -> UTCTime -> Either Text a -> STM ()
    updateMetrics breaker' now' result = do
      m <- readTVar (cbMetrics breaker')
      let newM = case result of
            Right _ ->
              m
                { totalRequests = totalRequests m + 1,
                  totalSuccesses = totalSuccesses m + 1,
                  failureRate = fromIntegral (totalFailures m + 1) / fromIntegral (totalRequests m + 1),
                  lastStateTransition = now'
                }
            Left _ ->
              m
                { totalRequests = totalRequests m + 1,
                  totalFailures = totalFailures m + 1,
                  failureRate = fromIntegral (totalFailures m + 1) / fromIntegral (totalRequests m + 1),
                  lastStateTransition = now'
                }
      writeTVar (cbMetrics breaker') newM

-- | Get the current state of a circuit breaker
getCircuitState :: CircuitBreaker -> IO CBState
getCircuitState = readTVarIO . cbStateVar

-- | Reset a circuit breaker to closed state
resetCircuitBreaker :: CircuitBreaker -> IO ()
resetCircuitBreaker breaker = do
  now <- getCurrentTime
  atomically $ do
    writeTVar (cbStateVar breaker) (CBSClosed 0)
    writeTVar (cbSuccesses breaker) 0
    writeTVar (cbFailures breaker) []
    writeTVar (cbMetrics breaker)
      CBMetrics
        { totalRequests = 0,
          totalFailures = 0,
          totalSuccesses = 0,
          failureRate = 0,
          lastStateTransition = now
        }
    if ffTrackHistory (cbFeatures breaker)
      then do
        hist <- readTVar (cbHistory breaker)
        writeTVar (cbHistory breaker) ((now, CBSClosed 0) : take 999 hist)
      else pure ()
