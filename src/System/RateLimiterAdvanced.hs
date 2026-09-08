module System.RateLimiterAdvanced where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, readTVarIO, writeTVar)
import qualified Data.Sequence as Seq
import Data.Time.Clock (NominalDiffTime, UTCTime, addUTCTime, diffUTCTime, getCurrentTime)

-- | Advanced rate limiter with multiple strategies
data RateLimiterAdvanced = RateLimiterAdvanced
  { limiterConfig :: RateConfig,
    limiterState :: TVar LimiterState,
    limiterMetrics :: TVar RateMetrics
  }

-- | Rate limiting strategies
data RateStrategy
  = TokenBucket
  | LeakyBucket
  | FixedWindow
  | SlidingWindow
  deriving (Show, Eq)

-- | Rate configuration
data RateConfig = RateConfig
  { rateStrategy :: RateStrategy,
    rateLimit :: Double,
    rateWindowSec :: Int,
    rateBurst :: Int,
    ratePenalty :: Double
  }

-- | Limiter state by strategy
data LimiterState
  = TokenState {tokens :: Double, lastRefill :: UTCTime}
  | LeakState {leaks :: Seq.Seq UTCTime}
  | WindowState {windowCounts :: [(UTCTime, Int)]}
  | SlidingState {slidingRequests :: Seq.Seq UTCTime}
  deriving (Show)

-- | Rate metrics
data RateMetrics = RateMetrics
  { totalRequests :: Int,
    totalAllowed :: Int,
    totalDenied :: Int,
    currentRate :: Double,
    penaltyApplied :: Int
  }

-- | Initialize advanced rate limiter
initRateLimiterAdvanced :: RateConfig -> IO RateLimiterAdvanced
initRateLimiterAdvanced config = do
  now <- getCurrentTime
  state <- newTVarIO $ initState (rateStrategy config) now
  metricsVar <-
    newTVarIO
      RateMetrics
        { totalRequests = 0,
          totalAllowed = 0,
          totalDenied = 0,
          currentRate = 0,
          penaltyApplied = 0
        }
  return $ RateLimiterAdvanced config state metricsVar
  where
    initState TokenBucket now = TokenState 0 now
    initState LeakyBucket _ = LeakState Seq.empty
    initState FixedWindow _ = WindowState []
    initState SlidingWindow _ = SlidingState Seq.empty

-- | Check request with advanced logic
checkRequestAdvanced :: RateLimiterAdvanced -> IO Bool
checkRequestAdvanced limiter = do
  now <- getCurrentTime
  atomically $ do
    state <- readTVar (limiterState limiter)
    let (allowed, newState) = evaluateStrategy state now
    writeTVar (limiterState limiter) newState
    return allowed
  where
    cfg = limiterConfig limiter
    rateLmt = rateLimit cfg
    winSec = realToFrac (rateWindowSec cfg) :: NominalDiffTime
    windowDur = winSec

    evaluateStrategy (TokenState tokens lastRefill) now =
      let refillRate = rateLmt
          elapsed = realToFrac $ diffUTCTime now lastRefill
          newTokens = min rateLmt (tokens + elapsed * refillRate)
       in if newTokens >= 1
             then (True, TokenState (newTokens - 1) now)
             else (False, TokenState newTokens now)
    evaluateStrategy (LeakState leaks) now =
      let winSize = realToFrac (rateWindowSec cfg) :: NominalDiffTime
          validLeaks = Seq.dropWhileL (\t -> diffUTCTime now t < winSize) leaks
          count = Seq.length validLeaks
       in if fromIntegral count < rateLmt
             then (True, LeakState (validLeaks Seq.|> now))
             else (False, LeakState validLeaks)
    evaluateStrategy (WindowState counts) now =
      let windowStart = addUTCTime (negate windowDur) now
          validCounts = filter (\(t, _) -> t > windowStart) counts
          total = sum (map snd validCounts)
       in if fromIntegral total < rateLmt
             then (True, WindowState ((now, 1) : validCounts))
             else (False, WindowState ((now, 1) : validCounts))
    evaluateStrategy (SlidingState reqs) now =
      let windowStartTime = addUTCTime (negate windowDur) now
          validReqs = Seq.dropWhileL (\t -> t < windowStartTime) reqs
       in if fromIntegral (Seq.length validReqs) < rateLmt
             then (True, SlidingState (validReqs Seq.|> now))
             else (False, SlidingState validReqs)

-- | Check with burst allowance
checkRequestWithBurst :: RateLimiterAdvanced -> IO Bool
checkRequestWithBurst limiter = do
  allowed <- checkRequestAdvanced limiter
  if not allowed
    then do
      -- Apply penalty
      atomically $ do
        m <- readTVar (limiterMetrics limiter)
        writeTVar
          (limiterMetrics limiter)
          m
            { penaltyApplied = penaltyApplied m + 1,
              currentRate = currentRate m * ratePenalty (limiterConfig limiter)
            }
      return False
    else return True

-- | Get current rate
getRateAdvanced :: RateLimiterAdvanced -> IO Double
getRateAdvanced limiter = readTVarIO (limiterMetrics limiter) >>= return . currentRate

-- | Reset limiter
resetRateLimiterAdvanced :: RateLimiterAdvanced -> IO ()
resetRateLimiterAdvanced limiter = do
  now <- getCurrentTime
  atomically $ do
    state <- readTVar (limiterState limiter)
    let newState = initState (rateStrategy (limiterConfig limiter)) now
    writeTVar (limiterState limiter) newState
    m <- readTVar (limiterMetrics limiter)
    writeTVar
      (limiterMetrics limiter)
      m
        { totalRequests = 0,
          totalAllowed = 0,
          totalDenied = 0,
          currentRate = 0,
          penaltyApplied = 0
        }
  where
    initState TokenBucket now = TokenState 0 now
    initState LeakyBucket _ = LeakState Seq.empty
    initState FixedWindow _ = WindowState []
    initState SlidingWindow _ = SlidingState Seq.empty
