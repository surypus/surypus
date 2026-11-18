{-# LANGUAGE OverloadedStrings #-}

-- | QuickCheck + unit property coverage for `System.Scheduler`.
--
-- 'System.Scheduler.calculateNextRun' is pure and is checked
-- deterministically; the STM/queue parts of `System.Scheduler` are
-- exercised with small deterministic 'IO' checks. It adds first coverage
-- for the scheduling layer (TASK-028 backlog: no spec existed for
-- `System.Scheduler`).
module System.SchedulerSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, choose, forAll)
import Test.QuickCheck.Property (Property, (===))
import Data.Time.Calendar (Day, fromGregorian, addDays, diffDays)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Control.Concurrent.STM (atomically, isEmptyTQueue, readTVar, tryReadTQueue)
import qualified Data.Map.Strict as Map

import System.Scheduler

-- | Small configuration so 'initScheduler' never overflows.
schedConfig :: SchedulerConfig
schedConfig = SchedulerConfig
  { schedulerTickInterval = 1000
  , schedulerMaxJobs = 50
  }

-- | Deterministic 'Day' generator (bounds keep everything terminating).
genDay :: Gen Day
genDay = do
  y <- choose (2000, 2030)
  m <- choose (1, 12)
  d <- choose (1, 28)
  pure $ fromGregorian y m d

-- | 'calculateNextRun' with a bounded, guaranteed-to-match offset.
prop_calculateNextRun_findExpectedDay :: (Day, Int) -> Property
prop_calculateNextRun_findExpectedDay (start, offset) =
  let offset' = abs offset
      pred d = diffDays d start == fromIntegral offset'
      expectedDay = addDays (fromIntegral offset') start
      result = calculateNextRun start pred
  in utctDay result === expectedDay

-- | 'calculateNextRun' always puts the result at midnight.
prop_calculateNextRun_atMidnight :: (Day, Int) -> Property
prop_calculateNextRun_atMidnight (start, offset) =
  let offset' = abs offset
      pred d = diffDays d start == fromIntegral offset'
      result = calculateNextRun start pred
  in utctDayTime result === secondsToDiffTime 0

spec :: Spec
spec = do
  describe "System.Scheduler.calculateNextRun" $ do
    it "returns the start day at midnight when the start day satisfies the predicate" $ do
      let start = fromGregorian 2026 1 1
          day = calculateNextRun start (\d -> d == start)
      utctDay day `shouldBe` start
      utctDayTime day `shouldBe` secondsToDiffTime 0

    it "skips non-matching days and returns the first matching one" $ do
      let start = fromGregorian 2026 1 1
          day = calculateNextRun start (\d -> d == fromGregorian 2026 1 5)
      utctDay day `shouldBe` fromGregorian 2026 1 5
      utctDayTime day `shouldBe` secondsToDiffTime 0

    it "crosses a year boundary" $ do
      let start = fromGregorian 2026 12 31
          day = calculateNextRun start (\d -> d == fromGregorian 2027 1 1)
      utctDay day `shouldBe` fromGregorian 2027 1 1
      utctDayTime day `shouldBe` secondsToDiffTime 0

    it "never jumps past the requested day (monotonic)" $ do
      let start = fromGregorian 2026 6 15
          day = calculateNextRun start (\d -> d == fromGregorian 2026 7 1)
      utctDay day `shouldBe` fromGregorian 2026 7 1

    prop "returns the first day at the requested offset"
         (forAll genDay $ \start ->
            forAll (choose (0 :: Int, 30)) $ \offset ->
              prop_calculateNextRun_findExpectedDay (start, offset))
    prop "returns the result at midnight"
         (forAll genDay $ \start ->
            forAll (choose (0 :: Int, 30)) $ \_offset ->
              prop_calculateNextRun_atMidnight (start, 0))

  describe "System.Scheduler.updateJobQueue" $ do
    it "indexes the job under its next-run key" $ do
      sched <- initScheduler schedConfig
      let job =
            ScheduledJob
              { jobId = 42
              , jobType = OneTime (UTCTime (fromGregorian 2026 7 7) (secondsToDiffTime 0))
              , jobAction = return ()
              , jobNextRun = UTCTime (fromGregorian 2026 7 7) (secondsToDiffTime 0)
              , jobEnabled = True
              }
      updateJobQueue sched job
      jobs <- atomically $ readTVar (schedulerJobs sched)
      case Map.lookup (jobNextRun job) jobs of
        Just [j] -> jobId j `shouldBe` 42
        _ -> fail "job was not stored under its next-run time"

  describe "System.Scheduler.scheduleOnce" $ do
    it "queues the job with the requested next run and enabled flag" $ do
      sched <- initScheduler schedConfig
      let t = UTCTime (fromGregorian 2026 5 5) (secondsToDiffTime 0)
      _ <- scheduleOnce sched t (return ())
      q <- atomically $ tryReadTQueue (schedulerQueue sched)
      case q of
        Nothing -> fail "expected one job in the scheduler queue"
        Just job -> do
          jobNextRun job `shouldBe` t
          jobEnabled job `shouldBe` True

    it "creates a scheduler with an empty queue and empty job map" $ do
      sched <- initScheduler schedConfig
      qEmpty <- atomically $ isEmptyTQueue (schedulerQueue sched)
      qEmpty `shouldBe` True
      jobsEmpty <- atomically $ readTVar (schedulerJobs sched) >>= pure . Map.null
      jobsEmpty `shouldBe` True
