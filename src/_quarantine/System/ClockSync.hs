module System.ClockSync where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, readTVarIO, writeTVar)
import Data.List (sort)
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime, NominalDiffTime, addUTCTime)

-- | Clock synchronization configuration
data ClockSyncConfig = ClockSyncConfig
  { syncInterval :: Int,
    syncToleranceU :: NominalDiffTime,
    maxClockDrift :: NominalDiffTime
  }

-- | Clock synchronization state
data ClockSync = ClockSync
  { clockOffsets :: TVar [NominalDiffTime],
    clockConfig :: ClockSyncConfig,
    lastSyncTime :: TVar UTCTime
  }

-- | Initialize clock synchronization
initClockSync :: ClockSyncConfig -> IO ClockSync
initClockSync config = do
  offsetsVar <- newTVarIO []
  now <- getCurrentTime
  lastVar <- newTVarIO now
  return $ ClockSync offsetsVar config lastVar

-- | Measure clock offset
measureClockOffset :: ClockSync -> IO NominalDiffTime
measureClockOffset sync = do
  -- Simplified: return 0 offset
  return 0

-- | Synchronize clocks
synchronizeClocks :: ClockSync -> IO ()
synchronizeClocks sync = do
  offsets <- sequence [measureClockOffset sync | _ <- [1 .. 5]]
  let validOffsets = filter (\o -> abs o <= syncToleranceU (clockConfig sync)) offsets
  case validOffsets of
    [] -> return ()
    os -> do
      now <- getCurrentTime
      atomically $ do
        writeTVar (clockOffsets sync) os
        writeTVar (lastSyncTime sync) now

-- | Get synchronized time
getSyncTime :: ClockSync -> IO UTCTime
getSyncTime sync = do
  offsets <- readTVarIO (clockOffsets sync)
  now <- getCurrentTime
  let avgOffset = if null offsets then 0 else sum offsets / fromIntegral (length offsets)
  return $ addUTCTime avgOffset now

-- | Check if clocks are synchronized
areClocksSynced :: ClockSync -> IO Bool
areClocksSynced sync = do
  offsets <- readTVarIO (clockOffsets sync)
  let maxOffset = if null offsets then 0 else maximum (map abs offsets)
  return $ maxOffset <= syncToleranceU (clockConfig sync)
