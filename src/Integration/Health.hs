
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
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
import Data.Aeson (ToJSON, FromJSON, genericToJSON, genericParseJSON, defaultOptions)
import GHC.Generics (Generic)
import Data.Time (UTCTime, getCurrentTime)
import DAL.ORMPool (ConnectionPool)
import DAL.Types (QueryResult(..), CommandResult(..))
import DAL.Database (runDb)
import Database.Persist.Sql (rawSql, rawExecute, PersistValue(..))

-- | Health status enumeration
data HealthStatus = Healthy | Degraded | Failed
  deriving (Show, Eq, Generic)

instance ToJSON HealthStatus
instance FromJSON HealthStatus

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
parseStatus t
  | t == "healthy" = Healthy
  | t == "degraded" = Degraded
  | t == "failed" = Failed
  | otherwise = Degraded

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
  _ <- runDb pool $ rawExecute sql [PersistText tenantId, PersistText adapterType]
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
  _ <- runDb pool $ rawExecute sql [PersistInt64 (fromIntegral minFailureCount)]
  return $ CommandSuccess []

parseHealthRow :: [PersistValue] -> IntegrationHealth
parseHealthRow [tid, atype, status, failCount, lastSuccess, lastFailure, errMsg, lastChecked] =
    let mStatus = case status of
                    PersistText "healthy" -> Healthy
                    PersistText "degraded" -> Degraded
                    _ -> Failed
        mFailCount = case failCount of
                       PersistInt64 n -> fromIntegral n
                       _ -> 0
        unwrapText pv = case pv of PersistText t -> t; _ -> ""
        unwrapMaybeUTCTime pv = case pv of PersistUTCTime t -> Just t; PersistNull -> Nothing; _ -> Nothing
        unwrapUTCTime pv = case pv of PersistUTCTime t -> t; _ -> read "1970-01-01 00:00:00 UTC"
        unwrapMaybeText pv = case pv of PersistText t -> Just t; PersistNull -> Nothing; _ -> Nothing
    in IntegrationHealth
        { ihTenantId = unwrapText tid
        , ihAdapterType = unwrapText atype
        , ihStatus = mStatus
        , ihFailureCount = mFailCount
        , ihLastSuccess = unwrapMaybeUTCTime lastSuccess
        , ihLastFailure = unwrapMaybeUTCTime lastFailure
        , ihErrorMessage = unwrapMaybeText errMsg
        , ihLastChecked = unwrapUTCTime lastChecked
        }
parseHealthRow _ = IntegrationHealth "" "" Healthy 0 Nothing Nothing Nothing (read "1970-01-01 00:00:00 UTC")

-- | Check if health status exceeds threshold
checkHealthThreshold :: IntegrationHealth -> Int -> Bool
checkHealthThreshold health threshold =
  ihFailureCount health >= threshold &&
  ihStatus health `elem` [Degraded, Failed]
