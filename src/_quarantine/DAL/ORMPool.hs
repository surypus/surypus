{-# LANGUAGE OverloadedStrings #-}

module DAL.ORMPool
  ( createPool
  , closePool
  , ConnectionPool
  ) where

import Control.Monad.Logger (runNoLoggingT)
import Data.ByteString.Char8 (pack)
import Database.Persist.Postgresql (createPostgresqlPool, ConnectionPool)

createPool :: IO ConnectionPool
createPool = runNoLoggingT $ createPostgresqlPool (pack "host=localhost port=5432 dbname=surypus user=postgres password=postgres") 10

closePool :: ConnectionPool -> IO ()
closePool _ = return ()
