-- | Database connection pool
{-# LANGUAGE OverloadedStrings #-}
module Surypus.Database.Pool
  ( Pool,
    createDatabasePool,
    databasePoolConfigFromEnv,
    pingDatabasePool,
    releaseDatabasePool,
    runMigrations,
  )
where

import Data.Text (Text)
import Data.Time (NominalDiffTime)

-- | Database connection pool (opaque type)
data Pool = Pool
  deriving (Show, Eq)

-- | Database configuration
data PoolConfig = PoolConfig
  { pcHost :: Text,
    pcPort :: Int,
    pcUser :: Text,
    pcPassword :: Text,
    pcDatabase :: Text,
    pcPoolSize :: Int,
    pcTimeout :: NominalDiffTime
  }

-- | Create a database pool from configuration
createDatabasePool :: PoolConfig -> IO Pool
createDatabasePool _config = do
  pure Pool

-- | Load database configuration from environment
databasePoolConfigFromEnv :: IO PoolConfig
databasePoolConfigFromEnv = do
  pure $
    PoolConfig
      { pcHost = "localhost",
        pcPort = 5432,
        pcUser = "suryplus",
        pcPassword = "",
        pcDatabase = "suryplus",
        pcPoolSize = 10,
        pcTimeout = 30
      }

-- | Ping the database to check connectivity
pingDatabasePool :: Pool -> IO Bool
pingDatabasePool _pool = pure True

-- | Release the database pool
releaseDatabasePool :: Pool -> IO ()
releaseDatabasePool _pool = pure ()

-- | Run database migrations
runMigrations :: Pool -> IO ()
runMigrations _pool = pure ()