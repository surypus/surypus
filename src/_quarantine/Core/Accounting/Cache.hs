-- | Cached Read Model - In-memory TTL cache for account read models
-- US-3-3: Read models Redis cache (in-memory TTL implementation)
{-# LANGUAGE OverloadedStrings #-}
module Core.Accounting.Cache
  ( ReadModelCache
  , mkReadModelCache
  , getCachedAccountReadModel
  , getCachedBalance
  , invalidateCache
  , clearCache
  , cacheStats
  ) where

import Data.Int (Int64)
import Data.Time (UTCTime, getCurrentTime, addUTCTime)
import Data.IORef (IORef, newIORef, readIORef, atomicModifyIORef')
import DAL.Database (ConnectionPool)
import System.Cache (CacheStats  (..))

import qualified Core.Accounting.ReadModel as RM

-- | Cache TTL in seconds
cacheTTL :: Double
cacheTTL = 10

-- | Read model cache state
data CacheState = CacheState
  { csModels :: [(Int64, (UTCTime, RM.AccountReadModel))]
  , chHits :: Int
  , chMisses :: Int
  }

-- | Read model cache handle
data ReadModelCache = ReadModelCache
  { rcState :: IORef CacheState
  , rcPool  :: ConnectionPool
  }

-- | Create a new read model cache
mkReadModelCache :: ConnectionPool -> IO ReadModelCache
mkReadModelCache pool = do
  ref <- newIORef CacheState
    { csModels = []
    , chHits = 0
    , chMisses = 0
    }
  pure $ ReadModelCache ref pool

-- | Get cached account read model (or compute and cache)
getCachedAccountReadModel :: ReadModelCache -> Int64 -> IO RM.AccountReadModel
getCachedAccountReadModel cache accountId = do
    let ReadModelCache ref pool = cache
    now <- getCurrentTime
    state <- readIORef ref
    case lookup accountId (csModels state) of
        Just (expiresAt, model) | expiresAt > now -> do
            atomicModifyIORef' ref $ \s ->
                (s { chHits = chHits s + 1 }, ())
            pure model
        _ -> do
            result <- RM.replayAccountEvents pool accountId ""
            case result of
                Left _ -> do
                    atomicModifyIORef' ref $ \s ->
                        (s { chMisses = chMisses s + 1 }, ())
                    pure $ emptyModel accountId now
                Right model -> do
                    let expiresAt = addUTCTime (realToFrac cacheTTL) now
                    atomicModifyIORef' ref $ \s ->
                        let updatedModels = (accountId, (expiresAt, model)) : filter (\(k, _) -> k /= accountId) (csModels s)
                            updatedState = s { csModels = updatedModels, chMisses = chMisses s + 1 }
                        in (updatedState, ())
                    pure model

-- | Get cached balance
getCachedBalance :: ReadModelCache -> Int64 -> IO Double
getCachedBalance cache accountId = do
  model <- getCachedAccountReadModel cache accountId
  pure $ RM.bsCurrentBalance (RM.armBalanceState model)

-- | Invalidate cache for a specific account
invalidateCache :: ReadModelCache -> Int64 -> IO ()
invalidateCache cache accountId =
  atomicModifyIORef' (rcState cache) $ \s ->
    ( s { csModels = filter (\(k, _) -> k /= accountId) (csModels s) }
    , ()
    )

-- | Clear all cached entries
clearCache :: ReadModelCache -> IO ()
clearCache cache =
  atomicModifyIORef' (rcState cache) $ \s ->
    ( s { csModels = [] }
    , ()
    )

-- | Get cache statistics
cacheStats :: ReadModelCache -> IO CacheStats
cacheStats cache = do
  state <- readIORef (rcState cache)
  pure CacheStats
    { csHits = fromIntegral (chHits state)
    , csMisses = fromIntegral (chMisses state)
    , csSize = fromIntegral (length (csModels state))
    }

-- | Create an empty read model
emptyModel :: Int64 -> UTCTime -> RM.AccountReadModel
emptyModel accountId now = RM.AccountReadModel
  { RM.armAccountId = accountId
  , RM.armCode = Nothing
  , RM.armName = Nothing
  , RM.armAccountType = Nothing
  , RM.armCurrencyId = Nothing
  , RM.armBalanceState = RM.BalanceState
      { RM.bsAccountId = accountId
      , RM.bsCurrentBalance = 0
      , RM.bsDebitTotal = 0
      , RM.bsCreditTotal = 0
      , RM.bsLastUpdated = now
      , RM.bsEventCount = 0
      }
  , RM.armCreatedAt = now
  , RM.armUpdatedAt = now
  }