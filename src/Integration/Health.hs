{-# LANGUAGE OverloadedStrings #-}
-- | Integration Health Monitoring
module Integration.Health
  ( HealthStatus(..)
  , IntegrationHealth(..)
  , recordSuccess
  , recordFailure
  , getHealthStatus
  , getUnhealthyIntegrations
  , checkHealthThreshold
  , parseStatus
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)
import Data.Time (UTCTime, getCurrentTime)
import DAL.ORMPool (ConnectionPool)
import DAL.Types (QueryResult(..), CommandResult(..))
import DAL.Database (runDb)
import Database.Persist.Sql (rawSql, rawExecute, Single(..), PersistValue(..))

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

-- | Parse status string to HealthStatus
parseStatus :: Text -> HealthStatus
parseStatus "healthy" = Healthy
parseStatus "degraded" = Degraded
parseStatus "failed" = Failed
parseStatus _ = Degraded

-- | Convert HealthStatus to text
statusToText :: HealthStatus -> Text
statusToText Healthy = "healthy"
statusToText Degraded = "degraded"
statusToText Failed = "failed"

-- | Record successful integration execution
recordSuccess :: ConnectionPool -> Text -> Text -> IO (CommandResult ())
recordSuccess pool tenantId adapterType = do
  now <- getCurrentTime
  let upsertSql = "INSERT INTO integration_health (tenant_id, adapter_type, status, failure_count, last_success, last_checked) \
                  \VALUES (?, ?, 'healthy', 0, ?, ?) \
                  \ON CONFLICT (tenant_id, adapter_type) DO UPDATE SET \
                  \  status = 'healthy', failure_count = 0, last_success = EXCLUDED.last_success, last_checked = EXCLUDED.last_checked"
  runDb pool $ rawExecute upsertSql
    [ PersistText tenantId
    , PersistText adapterType
    , PersistUTCTime now
    , PersistUTCTime now
    ]
  return $ CommandSuccess ()

-- | Record failed integration execution
recordFailure :: ConnectionPool -> Text -> Text -> Maybe Text -> IO (CommandResult ())
recordFailure pool tenantId adapterType mErrMsg = do
  now <- getCurrentTime
  let upsertSql = "INSERT INTO integration_health (tenant_id, adapter_type, status, failure_count, last_failure, error_message, last_checked) \
                  \VALUES (?, ?, 'failed', 1, ?, ?, ?) \
                  \ON CONFLICT (tenant_id, adapter_type) DO UPDATE SET \
                  \  status = CASE WHEN integration_health.failure_count >= 4 THEN 'failed' ELSE 'degraded' END, \
                  \  failure_count = integration_health.failure_count + 1, \
                  \  last_failure = EXCLUDED.last_failure, \
                  \  error_message = EXCLUDED.error_message, \
                  \  last_checked = EXCLUDED.last_checked"
      errMsg = maybe PersistNull PersistText mErrMsg
  runDb pool $ rawExecute upsertSql
    [ PersistText tenantId
    , PersistText adapterType
    , PersistUTCTime now
    , errMsg
    , PersistUTCTime now
    ]
  return $ CommandSuccess ()

-- | Get health status for a specific adapter
getHealthStatus :: ConnectionPool -> Text -> Text -> IO (CommandResult IntegrationHealth)
getHealthStatus pool tenantId adapterType = do
  let sql = "SELECT tenant_id, adapter_type, status, failure_count, last_success, last_failure, error_message, last_checked \
            \FROM integration_health WHERE tenant_id = ? AND adapter_type = ?"
  rows <- runDb pool $ rawSql sql [PersistText tenantId, PersistText adapterType]
  case rows of
    (Single tid : Single atype : Single status : Single failCount : Single lastSuccess : Single lastFailure : Single errMsg : Single lastChecked : _) -> do
      let mStatus = case status of
                      PersistText "healthy" -> Healthy
                      PersistText "degraded" -> Degraded
                      _ -> Failed
          mFailCount = case failCount of
                        PersistInt64 n -> fromIntegral n
                        _ -> 0
      return $ CommandSuccess $ IntegrationHealth
        { ihTenantId = tid
        , ihAdapterType = atype
        , ihStatus = mStatus
        , ihFailureCount = mFailCount
        , ihLastSuccess = lastSuccess
        , ihLastFailure = lastFailure
        , ihErrorMessage = errMsg
        , ihLastChecked = lastChecked
        }
    _ -> do
      now <- getCurrentTime
      return $ CommandSuccess $ IntegrationHealth
        { ihTenantId = tenantId
        , ihAdapterType = adapterType
        , ihStatus = Healthy
        , ihFailureCount = 0
        , ihLastSuccess = Nothing
        , ihLastFailure = Nothing
        , ihErrorMessage = Nothing
        , ihLastChecked = now
        }

-- | Get all unhealthy integrations for alerting
getUnhealthyIntegrations :: ConnectionPool -> Int -> IO (CommandResult [IntegrationHealth])
getUnhealthyIntegrations pool minFailureCount = do
  let sql = "SELECT tenant_id, adapter_type, status, failure_count, last_success, last_failure, error_message, last_checked \
            \FROM integration_health WHERE failure_count >= ? OR status IN ('degraded', 'failed') \
            \ORDER BY failure_count DESC"
  rows <- runDb pool $ rawSql sql [PersistInt64 (fromIntegral minFailureCount)]
  return $ CommandSuccess (map parseHealthRow rows)

parseHealthRow :: [PersistValue] -> IntegrationHealth
parseHealthRow (Single tid : Single atype : Single status : Single failCount : Single lastSuccess : Single lastFailure : Single errMsg : Single lastChecked : _) =
  let mStatus = case status of
                  PersistText "healthy" -> Healthy
                  PersistText "degraded" -> Degraded
                  _ -> Failed
      mFailCount = case failCount of
                    PersistInt64 n -> fromIntegral n
                    _ -> 0
  in IntegrationHealth
    { ihTenantId = tid
    , ihAdapterType = atype
    , ihStatus = mStatus
    , ihFailureCount = mFailCount
    , ihLastSuccess = lastSuccess
    , ihLastFailure = lastFailure
    , ihErrorMessage = errMsg
    , ihLastChecked = lastChecked
    }
parseHealthRow _ = IntegrationHealth "" "" Healthy 0 Nothing Nothing Nothing (read "1970-01-01 00:00:00 UTC")

-- | Check if health status exceeds threshold
checkHealthThreshold :: IntegrationHealth -> Int -> Bool
checkHealthThreshold health threshold =
  ihFailureCount health >= threshold &&
  ihStatus health `elem` [Degraded, Failed]
