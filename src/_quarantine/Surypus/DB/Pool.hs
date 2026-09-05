{-# LANGUAGE OverloadedStrings #-}

module Surypus.DB.Pool
  ( DBConfig(..)
  , Pool(..)
  , createPool
  , closePool
  , runQuery
  , poolStats
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (NominalDiffTime)
import Data.Time.Clock (secondsToNominalDiffTime)
import qualified Database.Persist.Postgresql as PG
import qualified Database.Persist.Sql as PS
import Data.Pool (destroyAllResources)
import Control.Monad.Logger (runNoLoggingT)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)
import Data.ByteString.Char8 (pack)
import Data.Maybe (fromMaybe)

-- | Database configuration
data DBConfig = DBConfig
  { dbHost :: !Text
  , dbPort :: !Int
  , dbName :: !Text
  , dbUser :: !Text
  , dbPassword :: !Text
  , dbPoolSize :: !Int
  , dbTimeout :: !NominalDiffTime
  } deriving (Show, Eq)

-- | Connection pool (thin wrapper)
newtype Pool = Pool
  { poolConn :: PG.ConnectionPool
  }

-- | Default DB config from environment or defaults
mkDBConfig :: IO DBConfig
mkDBConfig = do
  host <- maybe "localhost" T.pack <$> lookupEnv "DB_HOST"
  port <- fromMaybe 5432 . (>>= readMaybe) <$> lookupEnv "DB_PORT"
  name <- maybe "surypus" T.pack <$> lookupEnv "DB_NAME"
  user <- maybe "surypus" T.pack <$> lookupEnv "DB_USER"
  password <- maybe "surypus_password" T.pack <$> lookupEnv "DB_PASSWORD"
  poolSize <- fromMaybe 10 . (>>= readMaybe) <$> lookupEnv "DB_POOL_SIZE"
  let timeout = secondsToNominalDiffTime 30
  pure DBConfig
    { dbHost = host
    , dbPort = port
    , dbName = name
    , dbUser = user
    , dbPassword = password
    , dbPoolSize = poolSize
    , dbTimeout = timeout
    }

-- | Connection string from config

connString :: DBConfig -> Text
connString cfg =
  "host=" <> dbHost cfg
  <> " port=" <> T.pack (show (dbPort cfg))
  <> " dbname=" <> dbName cfg
  <> " user=" <> dbUser cfg
  <> " password=" <> dbPassword cfg

-- | Create connection pool from env
createPool :: IO Pool
createPool = do
  cfg <- mkDBConfig
  pool <- runNoLoggingT $ PG.createPostgresqlPool
    (pack (T.unpack (connString cfg)))
    (dbPoolSize cfg)
  pure (Pool pool)

-- | Close pool
closePool :: Pool -> IO ()
closePool (Pool p) = destroyAllResources p

-- | Run a query on a pool
runQuery :: Pool -> PS.SqlPersistT IO a -> IO a
runQuery (Pool p) action = PS.runSqlPool action p

-- | Pool statistics (placeholder)
poolStats :: Pool -> IO (Int64, Int64)
poolStats _pool = pure (0, 0)
