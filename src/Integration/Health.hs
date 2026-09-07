{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

-- | Integration Health Monitoring (Phase 1: stub)
module Integration.Health
  ( HealthStatus(..)
  , IntegrationHealth(..)
  , recordSuccess
  , recordFailure
  , getHealthStatus
  , getUnhealthyIntegrations
  , checkHealthThreshold
  ) where

import Data.Text (Text)
import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)
import Data.Time (UTCTime, getCurrentTime)
import DAL.ORMPool (ConnectionPool)
import DAL.Types (QueryResult(..))

-- | Health status enumeration
data HealthStatus = Healthy | Degraded | Failed
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Integration health record
data IntegrationHealth = IntegrationHealth
  { ihTenantId :: Text
  , ihAdapterType :: Text
  , ihStatus :: HealthStatus
  , ihFailureCount :: Int
  , ihLastSuccess :: Maybe UTCTime
  , ihLastFailure :: Maybe UTCTime
  , ihErrorMessage :: Maybe Text
  , ihLastChecked :: UTCTime
  } deriving (Show, Eq, Generic)

instance ToJSON IntegrationHealth
instance FromJSON IntegrationHealth

-- | Record successful integration execution
recordSuccess :: ConnectionPool -> Text -> Text -> IO (QueryResult ())
recordSuccess _pool _tenantId _adapterType = do
  return $ QuerySuccess ()

-- | Record failed integration execution
recordFailure :: ConnectionPool -> Text -> Text -> Maybe Text -> IO (QueryResult ())
recordFailure _pool _tenantId _adapterType _errorMessage = do
  return $ QuerySuccess ()

-- | Get health status for a specific adapter
getHealthStatus :: ConnectionPool -> Text -> Text -> IO (QueryResult IntegrationHealth)
getHealthStatus pool tenantId adapterType = do
  time <- Data.Time.getCurrentTime
  return $ QuerySuccess $
    IntegrationHealth tenantId adapterType Healthy 0 (Just time) Nothing Nothing time

-- | Get all unhealthy integrations for alerting
getUnhealthyIntegrations :: ConnectionPool -> Int -> IO (QueryResult [IntegrationHealth])
getUnhealthyIntegrations pool minFailureCount = do
  return $ QuerySuccess []

-- | Check if health status exceeds threshold
checkHealthThreshold :: IntegrationHealth -> Int -> Bool
checkHealthThreshold health threshold =
  ihFailureCount health >= threshold &&
  ihStatus health `elem` [Degraded, Failed]

-- | Parse status string to HealthStatus
parseStatus :: Text -> HealthStatus
parseStatus "healthy" = Healthy
parseStatus "degraded" = Degraded
parseStatus "failed" = Failed
parseStatus _ = Degraded
