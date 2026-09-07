-- | Cached Read Model - In-memory TTL cache (Phase 1: stub)
module Core.Accounting.Cache
  ( ReadModelCache(..)
  , mkReadModelCache
  , getCachedAccountReadModel
  , getCachedBalance
  , invalidateCache
  , clearCache
  , cacheStats
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import DAL.Database (ConnectionPool)

-- | Cache stats
data CacheStats = CacheStats
  { cacheHits :: !Int
  , cacheMisses :: !Int
  } deriving (Show, Eq)

-- | Read model cache (stub)
data ReadModelCache = ReadModelCache
  deriving (Show, Eq)

-- | Create a new cache
mkReadModelCache :: ConnectionPool -> IO ReadModelCache
mkReadModelCache _ = return ReadModelCache

-- | Get cached account read model (stub)
getCachedAccountReadModel :: ReadModelCache -> Int64 -> IO (Maybe Text)
getCachedAccountReadModel _ _ = return Nothing

-- | Get cached balance (stub)
getCachedBalance :: ReadModelCache -> Int64 -> IO (Maybe Double)
getCachedBalance _ _ = return Nothing

-- | Invalidate cache (stub)
invalidateCache :: ReadModelCache -> IO ()
invalidateCache _ = return ()

-- | Clear cache (stub)
clearCache :: ReadModelCache -> IO ()
clearCache _ = return ()

-- | Get cache stats (stub)
cacheStats :: ReadModelCache -> IO CacheStats
cacheStats _ = return (CacheStats 0 0)
