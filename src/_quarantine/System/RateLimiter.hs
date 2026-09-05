module System.RateLimiter where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Sequence as Seq
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime, NominalDiffTime)

-- | Token bucket rate limiter
data TokenBucket = TokenBucket
  { tbTokens :: TVar Double,
    tbLastRefill :: TVar UTCTime,
    tbRate :: Double,
    tbCapacity :: Double
  }

-- | Leaky bucket rate limiter
data LeakyBucket = LeakyBucket
  { lbQueue :: TVar (Seq.Seq UTCTime),
    lbRate :: Double,
    lbCapacity :: Int
  }

-- | Fixed window rate limiter
data FixedWindow = FixedWindow
  { fwCounts :: TVar [(UTCTime, Int)],
    fwLimit :: Int,
    fwWindowSec :: Int
  }

-- | Sliding window rate limiter
data SlidingWindow = SlidingWindow
  { swRequests :: TVar (Seq.Seq UTCTime),
    swLimit :: Int,
    swWindowSec :: Int
  }

-- | Initialize token bucket
initTokenBucket :: Double -> Double -> IO TokenBucket
initTokenBucket rate capacity = do
  now <- getCurrentTime
  var <- newTVarIO capacity
  lastVar <- newTVarIO now
  return $ TokenBucket var lastVar rate capacity

-- | Initialize leaky bucket
initLeakyBucket :: Int -> Double -> IO LeakyBucket
initLeakyBucket capacity rate = do
  var <- newTVarIO Seq.empty
  return $ LeakyBucket var rate capacity

-- | Initialize fixed window
initFixedWindow :: Int -> Int -> IO FixedWindow
initFixedWindow limit window = do
  var <- newTVarIO []
  return $ FixedWindow var limit window

-- | Initialize sliding window
initSlidingWindow :: Int -> Int -> IO SlidingWindow
initSlidingWindow limit window = do
  var <- newTVarIO Seq.empty
  return $ SlidingWindow var limit window

-- | Check token bucket
tbCheck :: TokenBucket -> IO Bool
tbCheck bucket = do
  now <- getCurrentTime
  atomically $ do
    tokens <- readTVar (tbTokens bucket)
    lastTime <- readTVar (tbLastRefill bucket)
    let elapsed = realToFrac $ diffUTCTime now lastTime
        newTokens = min (tbCapacity bucket) (tokens + elapsed * tbRate bucket)
    if newTokens >= 1
      then do
        writeTVar (tbTokens bucket) (newTokens - 1)
        writeTVar (tbLastRefill bucket) now
        return True
      else do
        writeTVar (tbLastRefill bucket) now
        return False

-- | Check leaky bucket
lbCheck :: LeakyBucket -> IO Bool
lbCheck bucket = do
  now <- getCurrentTime
  atomically $ do
    queue <- readTVar (lbQueue bucket)
    let rate = lbRate bucket
        windowSize = realToFrac (1 / rate) :: NominalDiffTime
        valid = Seq.dropWhileL (\t -> diffUTCTime now t < windowSize) queue
        count = Seq.length valid
    if count < lbCapacity bucket
      then do
        writeTVar (lbQueue bucket) (valid Seq.|> now)
        return True
      else return False

-- | Check fixed window
fwCheck :: FixedWindow -> IO Bool
fwCheck fw = do
  now <- getCurrentTime
  atomically $ do
    counts <- readTVar (fwCounts fw)
    let (windowStart, cnts) = spanValid counts now
        total = sum cnts
        valid = total < fwLimit fw
    if valid
      then do
        writeTVar (fwCounts fw) ((now, 1) : windowStart)
        return True
      else return False
  where
    spanValid entries cutoff =
      let (valid, _rest) = span (\(t, _) -> diffUTCTime cutoff t < fromIntegral (fwWindowSec fw)) entries
       in (valid, map snd valid)

-- | Check sliding window
swCheck :: SlidingWindow -> IO Bool
swCheck sw = do
  now <- getCurrentTime
  atomically $ do
    reqs <- readTVar (swRequests sw)
    let windowSize = fromIntegral (swWindowSec sw) :: NominalDiffTime
        valid = Seq.dropWhileL (\t -> diffUTCTime now t > windowSize) reqs
    if Seq.length valid < swLimit sw
      then do
        writeTVar (swRequests sw) (valid Seq.|> now)
        return True
      else return False

-- | Generic rate limiter interface
data RateLimiter
  = RLTokenBucket TokenBucket
  | RLLeakyBucket LeakyBucket
  | RLFixedWindow FixedWindow
  | RLSlidingWindow SlidingWindow

checkRateLimiter :: RateLimiter -> IO Bool
checkRateLimiter (RLTokenBucket b) = tbCheck b
checkRateLimiter (RLLeakyBucket b) = lbCheck b
checkRateLimiter (RLFixedWindow w) = fwCheck w
checkRateLimiter (RLSlidingWindow w) = swCheck w

-- | Rate limiter statistics
data RateStats = RateStats
  { checks :: Int,
    allowed :: Int,
    denied :: Int,
    currentRate :: Double
  }

getRateStats :: RateLimiter -> IO RateStats
getRateStats _ =
  return
    RateStats
      { checks = 0,
        allowed = 0,
        denied = 0,
        currentRate = 0
      }
