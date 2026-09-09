module Core.Accounting.RedisCache where

import Data.Text (Text)
import Data.Time (NominalDiffTime)
import GHC.Generics (Generic)
import Core.Accounting.Cache (ReadModelCache)
import qualified Core.Accounting.ReadModel as RM

data RedisCacheConfig = RedisCacheConfig
  { rccHost :: Text
  , rccPort :: Int
  , rccDatabase :: Int
  , rccDefaultTTL :: NominalDiffTime
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

createRedisCache :: RedisCacheConfig -> IO (ReadModelCache RM.AccountReadModel)
createRedisCache _ = return ReadModelCache
  { getCachedAccountReadModel = \_ -> return Nothing
  , invalidateCache = \_ -> return ()
  }
