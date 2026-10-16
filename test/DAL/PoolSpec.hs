{-# LANGUAGE OverloadedStrings #-}

-- | Tests for the connection-pool lifecycle helpers.
--
-- Pool creation is lazy, so these tests exercise 'closePool' without needing a
-- reachable database.
module DAL.PoolSpec (spec) where

import Control.Monad.Logger (runNoLoggingT)
import Data.ByteString.Char8 (pack)
import qualified DAL.Database as DB
import qualified DAL.ORMPool as ORMPool
import Database.Persist.Postgresql (createPostgresqlPool)
import Test.Hspec

spec :: Spec
spec = do
  describe "closePool" $ do
    it "destroys a pool without touching the database" $ do
      pool <- runNoLoggingT $ createPostgresqlPool (pack "host=127.0.0.1 port=1 dbname=x user=x password=x") 1
      DB.closePool pool

    it "destroys a pool through DAL.ORMPool" $ do
      pool <- runNoLoggingT $ createPostgresqlPool (pack "host=127.0.0.1 port=1 dbname=x user=x password=x") 1
      ORMPool.closePool pool
