{-# LANGUAGE OverloadedStrings #-}

-- | Alternative ORM pool handle.
--
-- Pool construction delegates to 'DAL.Database.createPool' so every pool in
-- the application uses the same environment-driven configuration.
module DAL.ORMPool
  ( createPool,
    closePool,
    ConnectionPool,
  )
where

import qualified DAL.Database as DB
import Data.Pool (destroyAllResources)
import Database.Persist.Postgresql (ConnectionPool)

createPool :: IO ConnectionPool
createPool = DB.createPool

closePool :: ConnectionPool -> IO ()
closePool = destroyAllResources
