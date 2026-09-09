module Core.Accounting.RedisCache where

import Data.Text (Text)
import GHC.Generics (Generic)

data RedisCacheConfig = RedisCacheConfig
  { rccHost :: Text
  , rccPort :: Int
  , rccDatabase :: Int
  , rccDefaultTTL :: Int
  , rccEventStreamName :: Text
  , rccMaxConnections :: Int
  } deriving (Show, Eq, Generic)

defaultRedisCacheConfig :: RedisCacheConfig
defaultRedisCacheConfig = RedisCacheConfig
  { rccHost = "localhost"
  , rccPort = 6379
  , rccDatabase = 0
  , rccDefaultTTL = 5
  , rccEventStreamName = "accounting-events"
  , rccMaxConnections = 10
  }

createRedisCache :: RedisCacheConfig -> IO ()
createRedisCache _ = return ()
