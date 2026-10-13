{-# LANGUAGE OverloadedStrings #-}

-- | Unit and property tests for System.MetricsCollector.
--
-- Covers metric recording, time-range querying, aggregation operations,
-- retention cleanup and the export stub.
--
-- Two things are pinned here. First, the empty-input boundary of every
-- aggregation: 'sum' and 'count' are 0 over an empty series, but 'avg' has
-- no defined value, so it must reject rather than emit a NaN that silently
-- poisons every downstream comparison. Second, the inclusive range and
-- cutoff boundaries.
--
-- Determinism note: 'recordMetric' stamps each point with 'getCurrentTime',
-- so any assertion about WHICH points survive a range filter or a cleanup
-- cannot be driven through it without depending on wall-clock deltas. Those
-- tests seed the exported 'metricsStore' TVar with controlled timestamps
-- instead; 'recordMetric' is only exercised for its own effect (a point is
-- appended, carrying the given value and tags).
module System.MetricsCollectorSpec (spec) where

import Control.Concurrent.STM (atomically, writeTVar)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Time as T
import System.MetricsCollector
  (    MapConfig (..),
    MetricPoint (..),
    MetricsCollector (..),
    aggregateMetrics,
    cleanupOldMetrics,
    exportMetrics,
    initMetricsCollector,
    queryMetrics,
    recordMetric,
  )
import Test.Hspec
import Test.QuickCheck

-- | A collector with no DB involvement; the store is a plain TVar.
mkCollector :: IO MetricsCollector
mkCollector = initMetricsCollector (MapConfig 60 24)

-- | Reference timestamp: 2026-01-01 00:00:00 UTC.
baseTime :: T.UTCTime
baseTime = T.UTCTime (T.fromGregorian 2026 1 1) 0

-- | A timestamp at @baseTime + n@ seconds.
mkTime :: Int -> T.UTCTime
mkTime n = T.addUTCTime (fromIntegral n) baseTime

-- | A point at @baseTime + n@ seconds with the given value.
mkPoint :: Int -> Double -> MetricPoint
mkPoint n v = MetricPoint (mkTime n) v Map.empty

-- | Seed the collector's store directly, bypassing 'recordMetric' so the
-- point timestamps are exact rather than "whenever this line ran".
seed :: MetricsCollector -> Text -> [MetricPoint] -> IO ()
seed collector name points =
  atomically $ writeTVar (metricsStore collector) (Map.singleton name points)

-- | A window covering every seeded timestamp.
wideRange :: (T.UTCTime, T.UTCTime)
wideRange = (mkTime (-100000), mkTime 100000)

-- | A window covering any real wall-clock timestamp 'recordMetric' could
-- have stamped (it uses 'getCurrentTime', so seeded @baseTime@ windows
-- never contain its points).
alwaysRange :: (T.UTCTime, T.UTCTime)
alwaysRange =
  ( T.UTCTime (T.fromGregorian 2000 1 1) 0,
    T.UTCTime (T.fromGregorian 2100 1 1) 0
  )

spec :: Spec
spec = describe "System.MetricsCollector" $ do
  describe "initMetricsCollector" $ do
    it "starts with an empty store" $ do
      collector <- mkCollector
      let (from, to) = wideRange
      points <- queryMetrics collector "cpu" from to
      map pointValue points `shouldBe` ([] :: [Double])

  describe "recordMetric" $ do
    it "appends a point carrying the given value" $ do
      collector <- mkCollector
      recordMetric collector "cpu" 0.5 Map.empty
      let (from, to) = alwaysRange
      points <- queryMetrics collector "cpu" from to
      length points `shouldBe` 1
      pointValue (head points) `shouldBe` 0.5

    it "appends a point carrying the given tags" $ do
      collector <- mkCollector
      recordMetric collector "cpu" 0.5 (Map.fromList [("host", "h1")])
      let (from, to) = alwaysRange
      points <- queryMetrics collector "cpu" from to
      pointTags (head points) `shouldBe` Map.fromList [("host", "h1")]

    it "accumulates rather than replaces" $ do
      collector <- mkCollector
      mapM_ (\v -> recordMetric collector "cpu" v Map.empty) [1.0, 2.0, 3.0]
      let (from, to) = alwaysRange
      points <- queryMetrics collector "cpu" from to
      length points `shouldBe` 3

    it "keeps metrics separated by name" $ do
      collector <- mkCollector
      recordMetric collector "cpu" 1.0 Map.empty
      recordMetric collector "mem" 2.0 Map.empty
      let (from, to) = alwaysRange
      cpu <- queryMetrics collector "cpu" from to
      mem <- queryMetrics collector "mem" from to
      map pointValue cpu `shouldBe` [1.0]
      map pointValue mem `shouldBe` [2.0]

  describe "queryMetrics" $ do
    it "returns nothing for an unknown metric name" $ do
      collector <- mkCollector
      seed collector "cpu" [mkPoint 0 1.0]
      let (from, to) = wideRange
      points <- queryMetrics collector "disk" from to
      map pointValue points `shouldBe` ([] :: [Double])

    it "includes a point inside the range" $ do
      collector <- mkCollector
      seed collector "cpu" [mkPoint 100 1.0]
      points <- queryMetrics collector "cpu" (mkTime 0) (mkTime 200)
      map pointValue points `shouldBe` [1.0]

    it "excludes a point after the range" $ do
      collector <- mkCollector
      seed collector "cpu" [mkPoint 300 1.0]
      points <- queryMetrics collector "cpu" (mkTime 0) (mkTime 200)
      map pointValue points `shouldBe` ([] :: [Double])

    it "excludes a point before the range" $ do
      collector <- mkCollector
      seed collector "cpu" [mkPoint 0 1.0]
      points <- queryMetrics collector "cpu" (mkTime 100) (mkTime 200)
      map pointValue points `shouldBe` ([] :: [Double])

    it "includes a point exactly on the lower boundary" $ do
      collector <- mkCollector
      seed collector "cpu" [mkPoint 100 1.0]
      points <- queryMetrics collector "cpu" (mkTime 100) (mkTime 200)
      map pointValue points `shouldBe` [1.0]

    it "includes a point exactly on the upper boundary" $ do
      collector <- mkCollector
      seed collector "cpu" [mkPoint 200 1.0]
      points <- queryMetrics collector "cpu" (mkTime 100) (mkTime 200)
      map pointValue points `shouldBe` [1.0]

    it "selects only the points inside the window, in store order" $ do
      collector <- mkCollector
      seed collector "cpu" (map (\n -> mkPoint n (fromIntegral n)) [0, 100, 200, 300])
      points <- queryMetrics collector "cpu" (mkTime 100) (mkTime 200)
      map (round . pointValue) points `shouldBe` [100, 200]

  describe "aggregateMetrics" $ do
    it "averages a non-empty series" $
      aggregateMetrics (map (mkPoint 0) [1.0, 2.0, 3.0]) "avg" `shouldBe` Right 2.0

    it "sums a non-empty series" $
      aggregateMetrics (map (mkPoint 0) [1.0, 2.0, 3.5]) "sum" `shouldBe` Right 6.5

    it "counts a non-empty series" $
      aggregateMetrics (map (mkPoint 0) [1.0, 2.0]) "count" `shouldBe` Right 2

    it "rejects an unknown operation" $
      aggregateMetrics [mkPoint 0 1.0] "median" `shouldSatisfy` either (const True) (const False)

    it "sums an empty series to zero" $
      aggregateMetrics [] "sum" `shouldBe` Right 0

    it "counts an empty series as zero" $
      aggregateMetrics [] "count" `shouldBe` Right 0

    it "rejects avg over an empty series instead of returning NaN" $
      aggregateMetrics [] "avg" `shouldSatisfy` either (const True) (const False)

    it "never yields a NaN average over any series" $ property $ \vals ->
      let xs = map (mkPoint 0) (vals :: [Double])
       in either (const True) (not . isNaN) (aggregateMetrics xs "avg")

    it "sum matches the plain fold for any series" $ property $ \vals ->
      aggregateMetrics (map (mkPoint 0) (vals :: [Double])) "sum" == Right (sum vals)

    it "count matches the length for any series" $ property $ \vals ->
      let xs = map (mkPoint 0) (vals :: [Double])
       in aggregateMetrics xs "count" == Right (fromIntegral (length xs) :: Double)

  describe "cleanupOldMetrics" $ do
    it "drops a point exactly on the cutoff" $ do
      collector <- mkCollector
      seed collector "cpu" (map (\n -> mkPoint n (fromIntegral n)) [50, 100])
      cleanupOldMetrics collector (mkTime 50)
      points <- queryMetrics collector "cpu" (mkTime 0) (mkTime 1000)
      map (round . pointValue) points `shouldBe` [100]

    it "keeps a point strictly newer than the cutoff" $ do
      collector <- mkCollector
      seed collector "cpu" [mkPoint 51 51]
      cleanupOldMetrics collector (mkTime 50)
      points <- queryMetrics collector "cpu" (mkTime 0) (mkTime 1000)
      map (round . pointValue) points `shouldBe` [51]

    it "removes every point when the cutoff is past all of them" $ do
      collector <- mkCollector
      seed collector "cpu" (map (\n -> mkPoint n (fromIntegral n)) [0, 50, 100])
      cleanupOldMetrics collector (mkTime 1000)
      points <- queryMetrics collector "cpu" (mkTime 0) (mkTime 2000)
      map pointValue points `shouldBe` ([] :: [Double])

    it "keeps every point when the cutoff precedes all of them" $ do
      collector <- mkCollector
      seed collector "cpu" (map (\n -> mkPoint n (fromIntegral n)) [100, 200])
      cleanupOldMetrics collector (mkTime 0)
      points <- queryMetrics collector "cpu" (mkTime 0) (mkTime 1000)
      length points `shouldBe` 2

    it "leaves other metric names untouched" $ do
      collector <- mkCollector
      -- mem survives (t=200 > cutoff 50), cpu is aged out (t=10 <= 50).
      atomically $ writeTVar (metricsStore collector) $
        Map.fromList
          [ ("cpu", [mkPoint 10 1.0]),
            ("mem", [mkPoint 200 2.0])
          ]
      cleanupOldMetrics collector (mkTime 50)
      let (from, to) = wideRange
      cpu <- queryMetrics collector "cpu" from to
      mem <- queryMetrics collector "mem" from to
      map pointValue cpu `shouldBe` ([] :: [Double])
      map pointValue mem `shouldBe` [2.0]

  describe "exportMetrics" $ do
    it "is a stub reporting zero exported rows" $ do
      collector <- mkCollector
      recordMetric collector "cpu" 1.0 Map.empty
      exportMetrics collector `shouldReturn` Right (0 :: Int64)
