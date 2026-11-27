-- | Canonical Pool type for Surypus.
-- All modules should import from here instead of DAL.Database.
module DAL.Pool
  ( ConnectionPool
  , createPool
  , createPoolWith
  , createPoolFromEnv
  , buildConnectionString
  , closePool
  , runDb
  ) where

import DAL.Database (ConnectionPool, createPool, createPoolWith, createPoolFromEnv, buildConnectionString, closePool, runDb)
