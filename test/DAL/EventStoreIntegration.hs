{-# LANGUAGE OverloadedStrings #-}

-- | Integration wrapper for "DAL.EventStoreSpec".
--
-- The event store talks to PostgreSQL, so its spec needs a live database. It is
-- wired into the suite but stays a no-op unless @SURYPUS_TEST_DATABASE_URL@ is
-- set, so a plain @cabal test@ works on a machine without a database while the
-- real round-trip is still exercised wherever one is available.
module DAL.EventStoreIntegration (spec) where

import Control.Monad.Logger (runNoLoggingT)

import qualified DAL.EventStoreSpec as EventStoreSpec
import qualified Data.ByteString.Char8 as BC
import DAL.Pool (closePool)
import Database.Persist.Postgresql (ConnectionPool, createPostgresqlPool)
import System.Environment (lookupEnv)
import Test.Hspec

spec :: Spec
spec = do
  mConn <- runIO (lookupEnv "SURYPUS_TEST_DATABASE_URL")
  case mConn of
    Nothing ->
      it "requires SURYPUS_TEST_DATABASE_URL" $
        pendingWith
          "set SURYPUS_TEST_DATABASE_URL=postgresql://user:pass@host:5432/db \
          \to run the event store integration tests"
    Just url ->
      beforeAll (runNoLoggingT (createPostgresqlPool (BC.pack url) 2)) $
        afterAll closePool EventStoreSpec.spec
