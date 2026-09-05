{-# LANGUAGE OverloadedStrings #-}
module System.Monitoring where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, readTVarIO, writeTVar)
import Control.Monad (when)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)

-- | Monitoring configuration
data MonitoringConfig = MonitoringConfig
  { metricsInterval :: Int,
    alertThresholds :: Map.Map Text Double,
    retentionPeriod :: Int
  }

-- | Monitoring state
data MonitoringState = MonitoringState
  { metricsStore :: TVar (Map.Map Text [(UTCTime, Double)]),
    alertsStore :: TVar [(UTCTime, Text, Text)],
    config :: MonitoringConfig
  }

-- | Initialize monitoring
initMonitoring :: MonitoringConfig -> IO MonitoringState
initMonitoring config = do
  metricsVar <- newTVarIO Map.empty
  alertsVar <- newTVarIO []
  return $ MonitoringState metricsVar alertsVar config

-- | Record metric
recordMetric :: MonitoringState -> Text -> Double -> IO ()
recordMetric state name value = do
  now <- getCurrentTime
  atomically $ do
    store <- readTVar (metricsStore state)
    let updated = Map.insertWith (++) name [(now, value)] store
    writeTVar (metricsStore state) updated
  checkThresholds state name value

-- | Check alert thresholds
checkThresholds :: MonitoringState -> Text -> Double -> IO ()
checkThresholds state name value = do
  let thresholds = alertThresholds (config state)
  case Map.lookup name thresholds of
    Just threshold -> when (value > threshold) $ do
      now <- getCurrentTime
      atomically $ do
        alerts <- readTVar (alertsStore state)
        writeTVar (alertsStore state) ((now, name, "threshold exceeded") : alerts)
    Nothing -> return ()

-- | Get metrics
getMetrics :: MonitoringState -> Text -> IO [(UTCTime, Double)]
getMetrics state name = do
  store <- readTVarIO (metricsStore state)
  return $ Map.findWithDefault [] name store

-- | Get alerts
getAlerts :: MonitoringState -> IO [(UTCTime, Text, Text)]
getAlerts = readTVarIO . alertsStore

-- | Alert configuration
data AlertConfig = AlertConfig
  { alertChannel :: Text,
    alertSeverity :: AlertSeverity,
    alertRecipients :: [Text]
  }

-- | Alert severity
data AlertSeverity
  = Low
  | Medium
  | High
  | Critical
  deriving (Show, Eq, Ord)

-- | Send alert
sendAlert :: AlertConfig -> Text -> Text -> IO ()
sendAlert config message severity = do
  -- Send via configured channel
  return ()
