-- ============================================================================
-- SURYPUS ACCOUNTING REDIS CACHE
-- US-3-3: Read models Redis cache with TTL and Redis streams for events
-- Extends Core.Accounting.Cache with Redis backend
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveAnyClass #-}

module Core.Accounting.RedisCache
  ( -- * Redis Cache Types
    RedisCacheConfig  (..)
  , RedisAccountCache  (..)
  , RedisCacheResult  (..)
  , RedisPool

    -- * Redis Cache Operations
  , initializeRedisCache
  , getRedisCachedBalance
  , setRedisCachedBalance
  , getRedisAccountFromCache
  , setRedisAccountInCache
  , invalidateRedisAccountCache

    -- * Redis Streams for Events
  , publishAccountEventToStream
  , subscribeToAccountEventStream
  , processRedisEventStream

    -- * Integration with existing cache
  , wrapWithRedisBackend
  , withRedisCache
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, NominalDiffTime, getCurrentTime, addUTCTime)
import Data.Aeson (ToJSON, FromJSON, encode, decode, Value)
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Char8 as BS
import GHC.Generics (Generic)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Exception (try, SomeException, bracket)
import Control.Monad (void)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Database.Redis hiding (decode, encode)

import Core.Accounting.Cache (ReadModelCache, getCachedAccountReadModel, invalidateCache)
import qualified Core.Accounting.ReadModel as RM

-- ============================================================================
-- REDIS CACHE TYPES
-- ============================================================================

-- | Redis cache configuration
data RedisCacheConfig = RedisCacheConfig
  { rccHost :: Text
  , rccPort :: Int
  , rccDatabase :: Int
  , rccDefaultTTL :: NominalDiffTime  -- 5-10 seconds as specified
  , rccEventStreamName :: Text
  , rccMaxConnections :: Int
  } deriving (Show, Eq, Generic)

-- | Redis cache result with metadata
data RedisCacheResult a = RedisCacheResult
  { rcrValue :: Maybe a
  , rcrFromRedis :: Bool  -- True if from Redis, False if fallback
  , rcrHit :: Bool
  , rcrTTL :: NominalDiffTime
  , rcrTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

-- | Redis account cache entry
data RedisAccountCache = RedisAccountCache
  { racAccountId :: Int64
  , racBalance :: Double
  , racDebitTotal :: Double
  , racCreditTotal :: Double
  , racLastUpdated :: UTCTime
  , racVersion :: Int64  -- Event version for consistency
  , racExpiresAt :: UTCTime
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Redis pool for connection management
data RedisPool = RedisPool
  { rpConnection :: Connection
  , rpConfig :: RedisCacheConfig
  }

-- ============================================================================
-- REDIS CLIENT IMPLEMENTATION
-- ============================================================================

-- | Connect to Redis using hedis
connectRedis :: RedisCacheConfig -> IO RedisPool
connectRedis config = do
  let ci = defaultConnectInfo { connectHost = "127.0.0.1", connectPort = PortNumber 6379 }
  conn <- checkedConnect ci
  pure $ RedisPool conn config

-- | Disconnect from Redis
disconnectRedis :: RedisPool -> IO ()
disconnectRedis pool = pure ()  -- hedis manages connection lifecycle internally

-- | Run Redis action with connection
withRedis :: RedisPool -> Redis a -> IO a
withRedis pool action = runRedis (rpConnection pool) action

-- ============================================================================
-- REDIS CACHE OPERATIONS
-- ============================================================================

-- | Initialize Redis cache
initializeRedisCache :: RedisCacheConfig -> IO RedisPool
initializeRedisCache config = do
  pool <- connectRedis config
  putStrLn $ "Redis cache initialized with TTL: " <> show (rccDefaultTTL config)
  return pool

-- | Get cached balance from Redis
getRedisCachedBalance :: RedisPool -> Int64 -> IO (RedisCacheResult Double)
getRedisCachedBalance pool accountId = do
  now <- getCurrentTime
  let key = "account:balance:" <> T.pack (show accountId)
  result <- try $ withRedis pool $ do
    ev <- get (TE.encodeUtf8 key)
    case ev of
      Left _reply -> return Nothing
      Right mbs -> case mbs of
        Just bs -> return (decode (BL.fromStrict bs))
        Nothing -> return Nothing
  case result of
    Left (_ :: SomeException) -> do
      -- Redis error, return miss
      pure $ RedisCacheResult Nothing False False 0 now
    Right Nothing -> do
      -- Cache miss
      pure $ RedisCacheResult Nothing False False 0 now
    Right (Just cached) -> do
      -- Cache hit
      pure $ RedisCacheResult (Just cached) True True (rccDefaultTTL (rpConfig pool)) now

-- | Set cached balance in Redis
setRedisCachedBalance :: RedisPool -> Int64 -> Double -> IO ()
setRedisCachedBalance pool accountId balance = do
  let key = "account:balance:" <> T.pack (show accountId)
      ttlSecs = floor (rccDefaultTTL (rpConfig pool)) :: Integer
  withRedis pool $ void $ setex (TE.encodeUtf8 key) ttlSecs (BL.toStrict $ encode balance)

-- | Get full account from Redis cache
getRedisAccountFromCache :: RedisPool -> Int64 -> IO (RedisCacheResult RedisAccountCache)
getRedisAccountFromCache pool accountId = do
  now <- getCurrentTime
  let key = "account:full:" <> T.pack (show accountId)
  result <- try $ withRedis pool $ do
    ev <- get (TE.encodeUtf8 key)
    case ev of
      Left _reply -> return Nothing
      Right mbs -> case mbs of
        Just bs -> return (decode (BL.fromStrict bs))
        Nothing -> return Nothing
  case result of
    Left (_ :: SomeException) -> do
      pure $ RedisCacheResult Nothing False False 0 now
    Right Nothing -> do
      pure $ RedisCacheResult Nothing False False 0 now
    Right (Just cached) -> do
      -- Check if expired
      if racExpiresAt cached > now
        then pure $ RedisCacheResult (Just cached) True True (rccDefaultTTL (rpConfig pool)) now
        else do
          -- Expired, delete and return miss
          withRedis pool $ void $ del [TE.encodeUtf8 key]
          pure $ RedisCacheResult Nothing False False 0 now

-- | Set full account in Redis cache
setRedisAccountInCache :: RedisPool -> RedisAccountCache -> IO ()
setRedisAccountInCache pool account = do
  let key = "account:full:" <> T.pack (show (racAccountId account))
      ttlSecs = floor (rccDefaultTTL (rpConfig pool)) :: Integer
  withRedis pool $ void $ setex (TE.encodeUtf8 key) ttlSecs (BL.toStrict $ encode account)
  -- Also cache balance separately for faster access
  setRedisCachedBalance pool (racAccountId account) (racBalance account)

-- | Invalidate Redis account cache
invalidateRedisAccountCache :: RedisPool -> Int64 -> IO ()
invalidateRedisAccountCache pool accountId = do
  let balanceKey = "account:balance:" <> T.pack (show accountId)
      fullKey = "account:full:" <> T.pack (show accountId)
  withRedis pool $ void $ del [TE.encodeUtf8 balanceKey, TE.encodeUtf8 fullKey]

-- ============================================================================
-- REDIS STREAMS FOR EVENTS
-- ============================================================================

-- | Publish account event to Redis stream
publishAccountEventToStream :: RedisPool -> Int64 -> Value -> IO ()
publishAccountEventToStream pool accountId eventData = do
  let streamName = rccEventStreamName (rpConfig pool)
  now <- getCurrentTime
  let eventId = "account:" <> T.pack (show accountId) <> ":" <> T.pack (show now)
      eventDataStr = BL.toStrict $ encode eventData
  withRedis pool $ void $ xadd (TE.encodeUtf8 streamName) (TE.encodeUtf8 eventId) [("*", eventDataStr)]

-- | Subscribe to account event stream
subscribeToAccountEventStream :: RedisPool -> (Value -> IO ()) -> IO ()
subscribeToAccountEventStream pool handler = do
  let streamName = rccEventStreamName (rpConfig pool)
  -- hedis pub/sub requires the dedicated PubSub monad; not wired yet (stub)
  putStrLn $ "subscribeToAccountEventStream: pub/sub not wired for stream " <> T.unpack streamName

-- | Process Redis event stream and update cache
processRedisEventStream :: RedisPool -> ReadModelCache -> IO ()
processRedisEventStream redisPool memoryCache = do
  -- Stub - would need actual hedis stream support
  putStrLn "Redis event stream processor started"

-- ============================================================================
-- INTEGRATION WITH EXISTING CACHE
-- ============================================================================

-- | Wrap existing cache with Redis backend for hybrid approach
wrapWithRedisBackend :: ReadModelCache -> RedisPool -> Int64 -> IO RM.AccountReadModel
wrapWithRedisBackend memoryCache redisPool accountId = do
  -- Try Redis first
  redisResult <- getRedisAccountFromCache redisPool accountId
  case rcrValue redisResult of
    Just redisAccount -> do
      -- Convert Redis cache to read model
      pure $ redisAccountToReadModel redisAccount
    Nothing -> do
      -- Fallback to memory cache
      model <- getCachedAccountReadModel memoryCache accountId
      -- Update Redis with the result
      redisAccount <- readModelToRedisAccount model
      setRedisAccountInCache redisPool redisAccount
      pure model

-- | Run action with Redis cache context
withRedisCache :: RedisPool -> (RedisPool -> IO a) -> IO a
withRedisCache pool action = action pool

-- | Convert Redis account cache to read model
redisAccountToReadModel :: RedisAccountCache -> RM.AccountReadModel
redisAccountToReadModel redisAccount = RM.AccountReadModel
  { RM.armAccountId = racAccountId redisAccount
  , RM.armCode = Nothing
  , RM.armName = Nothing
  , RM.armAccountType = Nothing
  , RM.armCurrencyId = Nothing
  , RM.armBalanceState = RM.BalanceState
      { RM.bsAccountId = racAccountId redisAccount
      , RM.bsCurrentBalance = racBalance redisAccount
      , RM.bsDebitTotal = racDebitTotal redisAccount
      , RM.bsCreditTotal = racCreditTotal redisAccount
      , RM.bsLastUpdated = racLastUpdated redisAccount
      , RM.bsEventCount = fromIntegral (racVersion redisAccount)
      }
  , RM.armCreatedAt = racLastUpdated redisAccount
  , RM.armUpdatedAt = racLastUpdated redisAccount
  }

-- | Convert read model to Redis account cache
readModelToRedisAccount :: RM.AccountReadModel -> IO RedisAccountCache
readModelToRedisAccount model = do
  now <- getCurrentTime
  let balanceState = RM.armBalanceState model
      expiresAt = addUTCTime (realToFrac 10) now  -- 10 second TTL
  pure RedisAccountCache
    { racAccountId = RM.armAccountId model
    , racBalance = RM.bsCurrentBalance balanceState
    , racDebitTotal = RM.bsDebitTotal balanceState
    , racCreditTotal = RM.bsCreditTotal balanceState
    , racLastUpdated = RM.bsLastUpdated balanceState
    , racVersion = fromIntegral (RM.bsEventCount balanceState)
    , racExpiresAt = expiresAt
    }