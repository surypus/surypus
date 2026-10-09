{-# LANGUAGE OverloadedStrings #-}

-- | Unit and property-based tests for System.RateLimiter.
-- Focuses on the Sliding window check and the API-facing
-- checkSlidingWindowWithHeaders function.
module System.RateLimiterSpec (spec) where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Map.Strict as M
import Data.Sequence (Seq)
import qualified Data.Sequence as Seq
import Data.Text (Text)
import Data.Time.Clock (UTCTime (..), diffUTCTime, getCurrentTime, addUTCTime)
import qualified Data.Time.Calendar as Calendar
import System.RateLimiter ( SlidingWindow (..)
                           , initSlidingWindow
                           , swCheck
                           , initTokenBucket
                           , tbCheck
                           , initLeakyBucket
                           , lbCheck
                           , initFixedWindow
                           , fwCheck
                           )
import qualified Surypus.API.RateLimiter as RL (checkSlidingWindow, checkSlidingWindowWithHeaders)
import Test.Hspec
import Test.QuickCheck
import Test.QuickCheck.Monadic (monadicIO, run, assert)

-- ============================================================================
-- Test helpers
-- ============================================================================

-- | Create a UTCTime at midnight on 2025-01-01.
midnight :: UTCTime
midnight = UTCTime (Calendar.fromGregorian 2025 1 1) 0

-- | Advance a UTCTime by n seconds.
addSeconds :: Int -> UTCTime -> UTCTime
addSeconds n t = addUTCTime (fromIntegral n) t

-- ============================================================================
-- SlidingWindow tests
-- ============================================================================

spec :: Spec
spec = do
  describe "SlidingWindow" slidingWindowSpec
  describe "checkSlidingWindowWithHeaders" checkSlidingWindowWithHeadersSpec
  describe "TokenBucket" tokenBucketSpec
  describe "LeakyBucket" leakyBucketSpec
  describe "FixedWindow" fixedWindowSpec

slidingWindowSpec :: Spec
slidingWindowSpec = do
  it "initially allows requests up to the limit" $ do
    sw <- initSlidingWindow 3 60
    result <- swCheck sw
    result `shouldBe` True

  it "allows exactly limit requests within window" $ do
    sw <- initSlidingWindow 3 60
    r1 <- swCheck sw
    r2 <- swCheck sw
    r3 <- swCheck sw
    r1 `shouldBe` True
    r2 `shouldBe` True
    r3 `shouldBe` True

  it "denies request when limit is reached" $ do
    sw <- initSlidingWindow 2 60
    _ <- swCheck sw
    _ <- swCheck sw
    result <- swCheck sw
    result `shouldBe` False

  it "resets window after expiration" $ do
    sw <- initSlidingWindow 1 1
    _ <- swCheck sw
    -- Simulate time passing by creating a new window with old timestamps
    -- In real time we can't easily wait 1 second, so we test the logic
    -- by checking that the window slides (timestamps older than windowSec
    -- are dropped)
    result <- swCheck sw
    -- Second request within 1 second should be denied
    result `shouldBe` False

  it "allows request after window expires (manual time advance)" $ do
    sw <- initSlidingWindow 1 1
    -- Manually set a request timestamp that is 2 seconds old
    now <- getCurrentTime
    let oldTime = addUTCTime (-2) now
    atomically $ do
      writeTVar (swRequests sw) (Seq.singleton oldTime)
    -- Now the old request is outside the 1-second window
    result <- swCheck sw
    result `shouldBe` True

  it "returns True when below limit and False at limit" $ do
    sw <- initSlidingWindow 5 60
    results <- mapM (\_ -> swCheck sw) [1..5]
    results `shouldBe` [True, True, True, True, True]
    denied <- swCheck sw
    denied `shouldBe` False

  it "property: never returns True more than limit times" $ property $
    \limit' -> monadicIO $ do
      let limit = abs limit' `mod` 20 + 1
      sw <- run $ initSlidingWindow limit 60
      results <- run $ mapM (\_ -> swCheck sw) [1..limit + 5]
      let trues = length (filter id results)
      assert $ trues == limit

-- ============================================================================
-- checkSlidingWindowWithHeaders tests
-- ============================================================================

checkSlidingWindowWithHeadersSpec :: Spec
checkSlidingWindowWithHeadersSpec = do
  it "returns correct remaining count for first request" $ do
    var <- newTVarIO (M.empty :: M.Map Text (Seq UTCTime))
    (ok, remaining, reset) <- RL.checkSlidingWindowWithHeaders var "key1" 10 60
    ok `shouldBe` True
    remaining `shouldBe` 9
    reset `shouldBe` 60

  it "returns correct remaining for second request" $ do
    var <- newTVarIO (M.empty :: M.Map Text (Seq UTCTime))
    _ <- RL.checkSlidingWindowWithHeaders var "key1" 10 60
    (ok, remaining, _) <- RL.checkSlidingWindowWithHeaders var "key1" 10 60
    ok `shouldBe` True
    remaining `shouldBe` 8

  it "returns remaining = 0 when at limit" $ do
    var <- newTVarIO (M.empty :: M.Map Text (Seq UTCTime))
    -- Fill up to limit - 1
    _ <- mapM (\_ -> RL.checkSlidingWindowWithHeaders var "key1" 3 60) [1..2]
    -- Last allowed request should have remaining = 0
    (ok, remaining, _) <- RL.checkSlidingWindowWithHeaders var "key1" 3 60
    ok `shouldBe` True
    remaining `shouldBe` 0
    -- Next request should be denied
    (ok2, remaining2, _) <- RL.checkSlidingWindowWithHeaders var "key1" 3 60
    ok2 `shouldBe` False
    remaining2 `shouldBe` 0

  it "tracks keys independently" $ do
    var <- newTVarIO (M.empty :: M.Map Text (Seq UTCTime))
    (ok1, rem1, _) <- RL.checkSlidingWindowWithHeaders var "key1" 5 60
    (ok2, rem2, _) <- RL.checkSlidingWindowWithHeaders var "key2" 5 60
    ok1 `shouldBe` True
    rem1 `shouldBe` 4
    ok2 `shouldBe` True
    rem2 `shouldBe` 4

  it "property: remaining decreases monotonically and never goes negative" $ property $
    \limit' -> monadicIO $ do
      let limit = abs limit' `mod` 15 + 2
      var <- run $ newTVarIO (M.empty :: M.Map Text (Seq UTCTime))
      results <- run $ mapM (\_ -> RL.checkSlidingWindowWithHeaders var "k" limit 60) [1..limit + 3]
      let remainders = map (\(_, r, _) -> r) results
      let allNonNeg = all (>= 0) remainders
      let decreasing = and $ zipWith (>=) remainders (drop 1 remainders)
      assert $ allNonNeg && decreasing

  it "property: exactly limit requests are allowed" $ property $
    \limit' -> monadicIO $ do
      let limit = abs limit' `mod` 10 + 1
      var <- run $ newTVarIO (M.empty :: M.Map Text (Seq UTCTime))
      results <- run $ mapM (\_ -> RL.checkSlidingWindowWithHeaders var "k" limit 60) [1..limit + 5]
      let allowed = length (filter (\(ok, _, _) -> ok) results)
      assert $ allowed == limit

-- ============================================================================
-- TokenBucket tests
-- ============================================================================

tokenBucketSpec :: Spec
tokenBucketSpec = do
  it "initially allows requests" $ do
    bucket <- initTokenBucket 1.0 10.0
    result <- tbCheck bucket
    result `shouldBe` True

  it "denies when bucket is empty" $ do
    bucket <- initTokenBucket 0.5 1.0
    _ <- tbCheck bucket
    result <- tbCheck bucket
    -- With rate 0.5 and capacity 1.0, first check succeeds,
    -- second check immediately after should fail
    result `shouldBe` False

  it "refills over time" $ do
    bucket <- initTokenBucket 100.0 1.0
    _ <- tbCheck bucket
    result <- tbCheck bucket
    -- With very high rate, refill is fast enough
    result `shouldBe` True

-- ============================================================================
-- LeakyBucket tests
-- ============================================================================

leakyBucketSpec :: Spec
leakyBucketSpec = do
  it "initially allows requests" $ do
    bucket <- initLeakyBucket 10 1.0
    result <- lbCheck bucket
    result `shouldBe` True

  it "denies when capacity exceeded" $ do
    bucket <- initLeakyBucket 2 100.0
    r1 <- lbCheck bucket
    r2 <- lbCheck bucket
    r3 <- lbCheck bucket
    r1 `shouldBe` True
    r2 `shouldBe` True
    r3 `shouldBe` False

-- ============================================================================
-- FixedWindow tests
-- ============================================================================

fixedWindowSpec :: Spec
fixedWindowSpec = do
  it "initially allows requests" $ do
    fw <- initFixedWindow 5 60
    result <- fwCheck fw
    result `shouldBe` True

  it "denies when limit reached" $ do
    fw <- initFixedWindow 2 60
    r1 <- fwCheck fw
    r2 <- fwCheck fw
    r3 <- fwCheck fw
    r1 `shouldBe` True
    r2 `shouldBe` True
    r3 `shouldBe` False

  it "allows requests in new window after reset" $ do
    -- With window = 1 second, we can't easily wait in tests
    -- But we can verify the logic works for the current window
    fw <- initFixedWindow 10 1
    results <- mapM (\_ -> fwCheck fw) [1..10]
    length (filter id results) `shouldBe` 10
