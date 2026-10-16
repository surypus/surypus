-- | Redis-backed read-model cache for account balances (US-3-3).
--
-- "Core.Accounting.Cache" covers the single-process case with an STM cache;
-- this module is the Redis-backed variant, so a balance can be shared across
-- processes and survive a restart. Every value is written with a TTL, so a
-- stale balance can never outlive the configured window, and a Redis failure
-- is never fatal - callers fall back to rebuilding from the event store.
{-# LANGUAGE DeriveGeneric #-}

{-# LANGUAGE OverloadedStrings #-}

module Core.Accounting.RedisCache
  ( -- * Configuration
    RedisCacheConfig (..)
  , defaultRedisCacheConfig
    -- * Cache handle
  , RedisCache
  , createRedisCache
  , closeRedisCache
    -- * Operations
  , getCachedBalance
  , putCachedBalance
  , deleteCachedBalance
    -- * Pure helpers (testable without a Redis server)
  , balanceKey
  , encodeBalance
  , decodeBalance
  ) where

import Control.Exception (SomeException, try)
import Data.Aeson (encode, decode)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LBS
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import GHC.Generics (Generic)
import qualified Database.Redis as R

-- | Where balances are cached and for how long.
data RedisCacheConfig = RedisCacheConfig
  { rccHost :: Text
  , rccPort :: Int
  , rccDatabase :: Int
  , rccDefaultTTL :: Int
  , rccEventStreamName :: Text
  , rccMaxConnections :: Int
  }
  deriving (Show, Eq, Generic)

-- | Defaults matching a local development setup: Redis on localhost with a
-- five second TTL - the shortest window that still absorbs a read burst.
defaultRedisCacheConfig :: RedisCacheConfig
defaultRedisCacheConfig =
  RedisCacheConfig
    { rccHost = "localhost"
    , rccPort = 6379
    , rccDatabase = 0
    , rccDefaultTTL = 5
    , rccEventStreamName = "accounting-events"
    , rccMaxConnections = 10
    }

-- | An open connection to the Redis instance backing the cache.
data RedisCache = RedisCache
  { rcConnection :: R.Connection
  , rcTTL :: Int
  }

-- | Connect to Redis. Returns 'Left' with the reason when the server cannot be
-- reached, so a caller can run without a cache instead of failing.
createRedisCache :: RedisCacheConfig -> IO (Either Text RedisCache)
createRedisCache cfg = do
  let ci =
        R.defaultConnectInfo
          { R.connectHost = T.unpack (rccHost cfg)
          , R.connectPort = R.PortNumber (fromIntegral (rccPort cfg))
          , R.connectDatabase = fromIntegral (rccDatabase cfg)
          , R.connectMaxConnections = max 1 (rccMaxConnections cfg)
          }
  result <- try (R.checkedConnect ci) :: IO (Either SomeException R.Connection)
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right conn -> Right (RedisCache conn (rccDefaultTTL cfg))

-- | Close the underlying connection.
closeRedisCache :: RedisCache -> IO ()
closeRedisCache = R.disconnect . rcConnection

-- | The Redis key under which a balance is stored.
balanceKey :: Int64 -> ByteString
balanceKey accountId =
  encodeUtf8 ("surypus:accounting:balance:" <> T.pack (show accountId))

-- | Serialise a balance for storage.
encodeBalance :: Double -> ByteString
encodeBalance = LBS.toStrict . encode

-- | Deserialise a stored balance. 'Nothing' for a missing or malformed value.
decodeBalance :: ByteString -> Maybe Double
decodeBalance = decode . LBS.fromStrict

-- | Look up a cached balance. 'Nothing' means a cache miss.
getCachedBalance :: RedisCache -> Int64 -> IO (Either Text (Maybe Double))
getCachedBalance cache accountId =
  fmap (either (Left . T.pack . show) (Right . maybe Nothing decodeBalance)) $
    R.runRedis (rcConnection cache) (R.get (balanceKey accountId))

-- | Store a balance with the configured TTL.
putCachedBalance :: RedisCache -> Int64 -> Double -> IO (Either Text ())
putCachedBalance cache accountId balance =
  fmap (either (Left . T.pack . show) (const (Right ()))) $
    R.runRedis (rcConnection cache) (R.setex (balanceKey accountId) (fromIntegral (rcTTL cache)) (encodeBalance balance))

-- | Drop a cached balance, for example after the account is written to.
deleteCachedBalance :: RedisCache -> Int64 -> IO (Either Text ())
deleteCachedBalance cache accountId =
  fmap (either (Left . T.pack . show) (const (Right ()))) $
    R.runRedis (rcConnection cache) (R.del [balanceKey accountId])
