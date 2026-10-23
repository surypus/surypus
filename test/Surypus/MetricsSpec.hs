{-# LANGUAGE OverloadedStrings #-}

-- | Unit and property tests for Surypus.Metrics.
--
-- Covers counter increments, gauge sets, histogram bucket routing,
-- value retrieval and Prometheus rendering. The module is STM-based
-- with no database involvement.
--
-- Two things are pinned here. First, the histogram bucket routing:
-- a value lands in the smallest bucket whose bound is >= the value,
-- or the largest bucket when the value exceeds every bound. Second,
-- the Prometheus exposition format: every metric name, type header
-- and value must be present and correctly formatted.
module Surypus.MetricsSpec (spec) where

import Control.Concurrent.STM (readTVarIO)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import Surypus.Metrics
  ( Metrics,
    flushMetrics,
    getMetricsValue,
    histBuckets,
    httpRequestDuration,
    initMetrics,
    recordCounter,
    recordGauge,
    recordTimer,
    renderPrometheus,
  )
import Test.Hspec
import Test.QuickCheck
import Test.QuickCheck.Monadic (monadicIO, run, assert)

-- | A metrics handle with no DB involvement.
mkMetrics :: IO Metrics
mkMetrics = initMetrics

spec :: Spec
spec = describe "Surypus.Metrics" $ do
  describe "initMetrics" $ do
    it "starts with all counters at zero" $ do
      metrics <- mkMetrics
      getMetricsValue metrics "http.requests_total" `shouldReturn` 0
      getMetricsValue metrics "http.requests_error" `shouldReturn` 0

    it "starts with histogram sum and count at zero" $ do
      metrics <- mkMetrics
      getMetricsValue metrics "http.request_duration_sum" `shouldReturn` 0
      getMetricsValue metrics "http.request_duration_count" `shouldReturn` 0

    it "starts with gauges at zero" $ do
      metrics <- mkMetrics
      getMetricsValue metrics "db.pool_connections" `shouldReturn` 0
      getMetricsValue metrics "job.queue_size" `shouldReturn` 0

  describe "recordCounter" $ do
    it "increments http.requests_total" $ do
      metrics <- mkMetrics
      recordCounter metrics "http.requests_total" 1
      getMetricsValue metrics "http.requests_total" `shouldReturn` 1

    it "increments http.requests_error" $ do
      metrics <- mkMetrics
      recordCounter metrics "http.requests_error" 1
      getMetricsValue metrics "http.requests_error" `shouldReturn` 1

    it "accumulates multiple increments" $ do
      metrics <- mkMetrics
      recordCounter metrics "http.requests_total" 1
      recordCounter metrics "http.requests_total" 2
      recordCounter metrics "http.requests_total" 3
      getMetricsValue metrics "http.requests_total" `shouldReturn` 6

    it "ignores unknown metric names" $ do
      metrics <- mkMetrics
      recordCounter metrics "unknown.metric" 42
      getMetricsValue metrics "unknown.metric" `shouldReturn` 0

    it "never yields a negative counter value" $ property $ \n ->
      let n' = abs (n :: Int64)
       in monadicIO $ do
            metrics <- run mkMetrics
            run $ recordCounter metrics "http.requests_total" n'
            val <- run $ getMetricsValue metrics "http.requests_total"
            assert (val >= 0)

  describe "recordTimer" $ do
    it "increments the histogram count" $ do
      metrics <- mkMetrics
      recordTimer metrics "http.request_duration" 0.5
      getMetricsValue metrics "http.request_duration_count" `shouldReturn` 1

    it "accumulates the histogram sum" $ do
      metrics <- mkMetrics
      recordTimer metrics "http.request_duration" 0.5
      recordTimer metrics "http.request_duration" 1.5
      getMetricsValue metrics "http.request_duration_sum" `shouldReturn` 2.0

    it "routes a value to the smallest bucket >= the value" $ do
      metrics <- mkMetrics
      recordTimer metrics "http.request_duration" 0.03
      -- 0.03 falls in the 0.05 bucket (smallest bound >= 0.03)
      buckets <- readTVarIO (histBuckets (httpRequestDuration metrics))
      M.lookup 0.05 buckets `shouldBe` Just 1

    it "routes a value exactly on a bound to that bound" $ do
      metrics <- mkMetrics
      recordTimer metrics "http.request_duration" 0.05
      buckets <- readTVarIO (histBuckets (httpRequestDuration metrics))
      M.lookup 0.05 buckets `shouldBe` Just 1

    it "routes a value exceeding all bounds to the largest bucket" $ do
      metrics <- mkMetrics
      recordTimer metrics "http.request_duration" 5.0
      buckets <- readTVarIO (histBuckets (httpRequestDuration metrics))
      M.lookup 2.5 buckets `shouldBe` Just 1

    it "ignores unknown metric names" $ do
      metrics <- mkMetrics
      recordTimer metrics "unknown.metric" 1.0
      getMetricsValue metrics "unknown.metric" `shouldReturn` 0

    it "never yields a negative histogram count" $ property $ \val ->
      let val' = abs (val :: Double)
       in monadicIO $ do
            metrics <- run mkMetrics
            run $ recordTimer metrics "http.request_duration" val'
            count <- run $ getMetricsValue metrics "http.request_duration_count"
            assert (count >= 0)

  describe "recordGauge" $ do
    it "sets db.pool_connections" $ do
      metrics <- mkMetrics
      recordGauge metrics "db.pool_connections" 42
      getMetricsValue metrics "db.pool_connections" `shouldReturn` 42

    it "sets job.queue_size" $ do
      metrics <- mkMetrics
      recordGauge metrics "job.queue_size" 7
      getMetricsValue metrics "job.queue_size" `shouldReturn` 7

    it "overwrites the previous gauge value" $ do
      metrics <- mkMetrics
      recordGauge metrics "db.pool_connections" 10
      recordGauge metrics "db.pool_connections" 20
      getMetricsValue metrics "db.pool_connections" `shouldReturn` 20

    it "ignores unknown metric names" $ do
      metrics <- mkMetrics
      recordGauge metrics "unknown.metric" 99
      getMetricsValue metrics "unknown.metric" `shouldReturn` 0

  describe "getMetricsValue" $ do
    it "returns 0 for unknown metric names" $ do
      metrics <- mkMetrics
      getMetricsValue metrics "nonexistent" `shouldReturn` 0

  describe "flushMetrics" $ do
    it "is a no-op that does not change any value" $ do
      metrics <- mkMetrics
      recordCounter metrics "http.requests_total" 5
      flushMetrics metrics
      getMetricsValue metrics "http.requests_total" `shouldReturn` 5

  describe "renderPrometheus" $ do
    it "contains the http.requests_total metric" $ do
      metrics <- mkMetrics
      recordCounter metrics "http.requests_total" 42
      output <- renderPrometheus metrics
      T.isInfixOf "surypus_http_requests_total 42" output `shouldBe` True

    it "contains the http.requests_error metric" $ do
      metrics <- mkMetrics
      recordCounter metrics "http.requests_error" 3
      output <- renderPrometheus metrics
      T.isInfixOf "surypus_http_requests_error_total 3" output `shouldBe` True

    it "contains the histogram sum and count" $ do
      metrics <- mkMetrics
      recordTimer metrics "http.request_duration" 1.5
      output <- renderPrometheus metrics
      T.isInfixOf "surypus_http_request_duration_seconds_sum 1.5" output `shouldBe` True
      T.isInfixOf "surypus_http_request_duration_seconds_count 1" output `shouldBe` True

    it "contains the db.pool_connections gauge" $ do
      metrics <- mkMetrics
      recordGauge metrics "db.pool_connections" 8
      output <- renderPrometheus metrics
      T.isInfixOf "surypus_db_pool_connections 8" output `shouldBe` True

    it "contains the job.queue_size gauge" $ do
      metrics <- mkMetrics
      recordGauge metrics "job.queue_size" 2
      output <- renderPrometheus metrics
      T.isInfixOf "surypus_job_queue_size 2" output `shouldBe` True

    it "contains TYPE headers for all metrics" $ do
      metrics <- mkMetrics
      output <- renderPrometheus metrics
      T.isInfixOf "# TYPE surypus_http_requests_total counter" output `shouldBe` True
      T.isInfixOf "# TYPE surypus_http_request_duration_seconds histogram" output `shouldBe` True
      T.isInfixOf "# TYPE surypus_http_requests_error_total counter" output `shouldBe` True
      T.isInfixOf "# TYPE surypus_db_pool_connections gauge" output `shouldBe` True
      T.isInfixOf "# TYPE surypus_job_queue_size gauge" output `shouldBe` True

    it "contains HELP headers for all metrics" $ do
      metrics <- mkMetrics
      output <- renderPrometheus metrics
      T.isInfixOf "# HELP surypus_http_requests_total" output `shouldBe` True
      T.isInfixOf "# HELP surypus_http_request_duration_seconds" output `shouldBe` True
      T.isInfixOf "# HELP surypus_http_requests_error_total" output `shouldBe` True
      T.isInfixOf "# HELP surypus_db_pool_connections" output `shouldBe` True
      T.isInfixOf "# HELP surypus_job_queue_size" output `shouldBe` True

    it "contains the +Inf bucket" $ do
      metrics <- mkMetrics
      recordTimer metrics "http.request_duration" 0.5
      output <- renderPrometheus metrics
      T.isInfixOf "le=\"+Inf\"" output `shouldBe` True

    it "contains all histogram bucket bounds" $ do
      metrics <- mkMetrics
      output <- renderPrometheus metrics
      mapM_
        (\bound -> T.isInfixOf ("le=\"" <> fmtBound bound <> "\"") output `shouldBe` True)
        [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5]

    it "reflects counter values in the output" $ property $ \n ->
      let n' = abs (n :: Int)
       in monadicIO $ do
            metrics <- run mkMetrics
            run $ recordCounter metrics "http.requests_total" (fromIntegral n')
            output <- run $ renderPrometheus metrics
            assert (T.isInfixOf ("surypus_http_requests_total " <> T.pack (show n')) output)

-- | Format a bucket bound the same way the module does.
fmtBound :: Double -> Text
fmtBound = T.pack . show
