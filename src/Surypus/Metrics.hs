{-# LANGUAGE OverloadedStrings #-}

-- | Metrics collection and Prometheus exposition
module Surypus.Metrics
  ( Metrics,
    initMetrics,
    recordCounter,
    recordTimer,
    recordGauge,
    httpRequestsTotal,
    httpRequestDuration,
    histBuckets,
    httpRequestsError,
    dbPoolConnections,
    jobQueueSize,
    flushMetrics,
    getMetricsValue,
    renderPrometheus,
  )
where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVarIO, readTVar, modifyTVar', writeTVar)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T

-- | Simple counter type
newtype Counter = Counter (TVar Int64)

-- | Simple gauge type
newtype Gauge = Gauge (TVar Double)

-- | Histogram buckets
data Histogram = Histogram
  { histBuckets :: TVar (Map Double Int64)
  , histSum     :: TVar Double
  , histCount   :: TVar Int64
  }

-- | Metrics handle containing STM counters
data Metrics = Metrics
  { httpRequestsTotal :: Counter
  , httpRequestDuration :: Histogram
  , httpRequestsError :: Counter
  , dbPoolConnections :: Gauge
  , jobQueueSize :: Gauge
  }

-- | Initialize metrics collection
initMetrics :: IO Metrics
initMetrics = do
  reqTotal <- Counter <$> newTVarIO 0
  reqError <- Counter <$> newTVarIO 0
  hb <- newTVarIO $ M.fromList [(0.005, 0), (0.01, 0), (0.025, 0), (0.05, 0), (0.1, 0), (0.25, 0), (0.5, 0), (1.0, 0), (2.5, 0)]
  histSumVar <- newTVarIO 0
  histCountVar <- newTVarIO 0
  poolConn <- Gauge <$> newTVarIO 0
  queueSz <- Gauge <$> newTVarIO 0
  pure $ Metrics reqTotal (Histogram hb histSumVar histCountVar) reqError poolConn queueSz

-- | Record a counter increment
recordCounter :: Metrics -> Text -> Int64 -> IO ()
recordCounter metrics name n = do
  case name of
    "http.requests_total" -> incCounter (httpRequestsTotal metrics) n
    "http.requests_error" -> incCounter (httpRequestsError metrics) n
    _ -> pure ()

-- | Record a timer measurement (seconds)
recordTimer :: Metrics -> Text -> Double -> IO ()
recordTimer metrics name val = do
  case name of
    "http.request_duration" -> recordHistogram (httpRequestDuration metrics) val
    _ -> pure ()

-- | Record a gauge value
recordGauge :: Metrics -> Text -> Double -> IO ()
recordGauge metrics name val = do
  case name of
    "db.pool_connections" -> setGauge (dbPoolConnections metrics) val
    "job.queue_size" -> setGauge (jobQueueSize metrics) val
    _ -> pure ()

incCounter :: Counter -> Int64 -> IO ()
incCounter (Counter var) n = atomically $ modifyTVar' var (+ n)

setGauge :: Gauge -> Double -> IO ()
setGauge (Gauge var) val = atomically $ writeTVar var val

recordHistogram :: Histogram -> Double -> IO ()
recordHistogram hist val = atomically $ do
  modifyTVar' (histSum hist) (+ val)
  modifyTVar' (histCount hist) (+ 1)
  buckets <- readTVar (histBuckets hist)
  let sortedBounds = M.keys buckets
      targetBound = case filter (>= val) sortedBounds of
        (b:_) -> b
        []    -> last sortedBounds
  modifyTVar' (histBuckets hist) (M.adjust (+ 1) targetBound)

-- | Flush metrics (no-op)
flushMetrics :: Metrics -> IO ()
flushMetrics _ = pure ()

-- | Get current metrics value for testing
getMetricsValue :: Metrics -> Text -> IO Double
getMetricsValue metrics name = do
  case name of
    "http.requests_total" -> readCounter (httpRequestsTotal metrics)
    "http.requests_error" -> readCounter (httpRequestsError metrics)
    "http.request_duration_sum" -> readTVarIO (histSum (httpRequestDuration metrics))
    "http.request_duration_count" -> fromIntegral <$> readTVarIO (histCount (httpRequestDuration metrics))
    _ -> pure 0

readCounter :: Counter -> IO Double
readCounter (Counter var) = fromIntegral <$> readTVarIO var

fmtDouble :: Double -> Text
fmtDouble d = T.pack (show d)

-- | Render all metrics in Prometheus text format
renderPrometheus :: Metrics -> IO Text
renderPrometheus metrics = do
  total <- readCounter (httpRequestsTotal metrics)
  errors <- readCounter (httpRequestsError metrics)
  durSum <- readTVarIO (histSum (httpRequestDuration metrics))
  durCount <- readTVarIO (histCount (httpRequestDuration metrics))
  buckets <- readTVarIO (histBuckets (httpRequestDuration metrics))
  let Gauge poolVar = dbPoolConnections metrics
  let Gauge queueVar = jobQueueSize metrics
  poolConn <- readTVarIO poolVar
  queueSz <- readTVarIO queueVar

  let header = T.unlines
        [ "# HELP surypus_http_requests_total Total HTTP requests"
        , "# TYPE surypus_http_requests_total counter"
        , "surypus_http_requests_total " <> fmtDouble total
        , ""
        , "# HELP surypus_http_request_duration_seconds HTTP request duration in seconds"
        , "# TYPE surypus_http_request_duration_seconds histogram"
        , "surypus_http_request_duration_seconds_sum " <> fmtDouble durSum
        , "surypus_http_request_duration_seconds_count " <> T.pack (show durCount)
        ]
      bucketLines = T.unlines (map (\(bound, count) ->
          "surypus_http_request_duration_seconds_bucket{le=\"" <> fmtDouble bound <> "\"} " <> T.pack (show count)
          ) (M.toList buckets))
      infBucket = "surypus_http_request_duration_seconds_bucket{le=\"+Inf\"} " <> T.pack (show durCount)
      errorMetrics = T.unlines
        [ ""
        , "# HELP surypus_http_requests_error_total Total HTTP error responses (5xx)"
        , "# TYPE surypus_http_requests_error_total counter"
        , "surypus_http_requests_error_total " <> fmtDouble errors
        ]
      poolMetrics = T.unlines
        [ ""
        , "# HELP surypus_db_pool_connections Current DB pool connections"
        , "# TYPE surypus_db_pool_connections gauge"
        , "surypus_db_pool_connections " <> fmtDouble poolConn
        ]
      queueMetrics = T.unlines
        [ ""
        , "# HELP surypus_job_queue_size Current job queue size"
        , "# TYPE surypus_job_queue_size gauge"
        , "surypus_job_queue_size " <> fmtDouble queueSz
        ]
  pure $ T.concat [header, bucketLines, "\n", infBucket, "\n", errorMetrics, poolMetrics, queueMetrics]