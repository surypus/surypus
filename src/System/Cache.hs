-- | Cache module - In-memory cache with STM support
module System.Cache where

import Control.Concurrent.STM (STM, TVar, newTVarIO, readTVar, writeTVar)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)

-- | Cache entry
data CacheEntry a = CacheEntry
  { ceKey :: Text,
    ceValue :: a,
    ceExpires :: Maybe UTCTime
  }
  deriving (Show, Eq)

-- | Cache statistics
data CacheStats = CacheStats
  { csHits :: Int64,
    csMisses :: Int64,
    csSize :: Int64
  }
  deriving (Show, Eq)

-- | Calculate hit rate
calcHitRate :: CacheStats -> Double
calcHitRate cs
  | total == 0 = 0
  | otherwise = fromIntegral (csHits cs) / fromIntegral total
  where
    total = csHits cs + csMisses cs

-- | Check if entry is expired
isExpired :: CacheEntry a -> UTCTime -> Bool
isExpired ce now = case ceExpires ce of
  Nothing -> False
  Just expiryTime -> now > expiryTime

-- | STM-based cache for thread-safe operations
data STMCache k v = STMCache
  { stmCache :: TVar [(k, v)],
    stmMaxSize :: Int
  }

-- | Create new STM cache
newSTMCache :: Int -> IO (STMCache k v)
newSTMCache maxSize = STMCache <$> newTVarIO [] <*> pure maxSize

-- | Get from STM cache
stmCacheGet :: (Eq k) => k -> STMCache k v -> STM (Maybe v)
stmCacheGet key (STMCache cache _) = do
  entries <- readTVar cache
  pure $ lookup key entries

-- | Put to STM cache
stmCachePut :: (Eq k) => k -> v -> STMCache k v -> STM ()
stmCachePut key val (STMCache cache maxSize) = do
  entries <- readTVar cache
  let filtered = filter (\(k, _) -> k /= key) entries
      newEntries = take maxSize $ (key, val) : filtered
  writeTVar cache newEntries

-- | Delete from STM cache
stmCacheDelete :: (Eq k) => k -> STMCache k v -> STM ()
stmCacheDelete key (STMCache cache _) = do
  entries <- readTVar cache
  writeTVar cache $ filter (\(k, _) -> k /= key) entries

-- | Clear STM cache
stmCacheClear :: STMCache k v -> STM ()
stmCacheClear (STMCache cache _) = writeTVar cache []

-- | Get cache size
stmCacheSize :: STMCache k v -> STM Int
stmCacheSize (STMCache cache _) = length <$> readTVar cache

-- | Optimized VAT calculation with INLINE
{-# INLINE calcVATStrict #-}
calcVATStrict :: Double -> Double -> Double
calcVATStrict amount rate = amount * (rate / 100.0)

-- | Optimized tax inclusive calculation with INLINE
{-# INLINE calcTaxInclusiveStrict #-}
calcTaxInclusiveStrict :: Double -> Double -> Double
calcTaxInclusiveStrict amount rate = amount * (1.0 + rate / 100.0)
