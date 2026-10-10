-- | Cached Read Model - Thread-safe in-memory STM cache for account balances.
-- Phase 3 (US-3-3): Read-model caching with TTL-like behavior via bounded size.
module Core.Accounting.Cache
  ( ReadModelCache(..)
  , CacheStats(..)
  , mkReadModelCache
  , getCachedBalance
  , putCachedBalance
  , getCachedAccountReadModel
  , invalidateCache
  , clearCache
  , cacheStats
  ) where

import Control.Concurrent.STM (TVar, atomically, modifyTVar', newTVarIO, readTVarIO)
import Data.Int (Int64)
import Data.Text (Text)
import System.Cache (STMCache, newSTMCache, stmCacheClear, stmCacheDelete, stmCacheGet, stmCachePut, stmCacheSize)

-- | Cache statistics for observability
data CacheStats = CacheStats
  { csHits   :: !Int
  , csMisses :: !Int
  , csSize   :: !Int
  } deriving (Show, Eq)

-- | Thread-safe read model cache using STM.
-- Backed by 'System.Cache.STMCache' with LRU eviction via bounded size.
data ReadModelCache = ReadModelCache
  { rcCache   :: STMCache Int64 Double
  , rcHits    :: TVar Int
  , rcMisses  :: TVar Int
  }

-- | Create a new cache with the given maximum size.
-- When the cache reaches maxSize, the least recently used entry is evicted.
mkReadModelCache :: Int -> IO ReadModelCache
mkReadModelCache maxSize = do
  cache <- newSTMCache maxSize
  hits <- newTVarIO 0
  misses <- newTVarIO 0
  return $ ReadModelCache cache hits misses

-- | Look up a cached balance.
-- Returns 0.0 for a cache miss (account not cached yet).
-- Thread-safe: concurrent STM access is atomic.
getCachedBalance :: ReadModelCache -> Int64 -> IO Double
getCachedBalance cache key = do
  mval <- atomically $ stmCacheGet key (rcCache cache)
  case mval of
    Just val -> do
      atomically $ modifyTVar' (rcHits cache) (+1)
      return val
    Nothing -> do
      atomically $ modifyTVar' (rcMisses cache) (+1)
      return 0.0

-- | Store a balance in the cache (or update an existing entry).
-- Uses LRU eviction: inserting at the front of the list.
putCachedBalance :: ReadModelCache -> Int64 -> Double -> IO ()
putCachedBalance cache key val = atomically $ stmCachePut key val (rcCache cache)

-- | Get cached account read model metadata (reserved for future use).
-- Currently returns Nothing; will be populated with AccountReadModel when
-- the read model is enhanced to support full serialization.
getCachedAccountReadModel :: ReadModelCache -> Int64 -> IO (Maybe Text)
getCachedAccountReadModel _ _ = return Nothing

-- | Remove a single entry from the cache.
invalidateCache :: ReadModelCache -> Int64 -> IO ()
invalidateCache cache key = atomically $ stmCacheDelete key (rcCache cache)

-- | Clear all entries from the cache (does not reset statistics).
clearCache :: ReadModelCache -> IO ()
clearCache cache = atomically $ stmCacheClear (rcCache cache)

-- | Return current cache statistics.
cacheStats :: ReadModelCache -> IO CacheStats
cacheStats cache = do
  hits <- readTVarIO (rcHits cache)
  misses <- readTVarIO (rcMisses cache)
  size <- atomically $ stmCacheSize (rcCache cache)
  return $ CacheStats hits misses size
