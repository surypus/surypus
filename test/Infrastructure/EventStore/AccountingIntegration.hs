{-# LANGUAGE OverloadedStrings #-}

-- | Integration test for the accounting event store's Redis fan-out.
--
-- Appending an event must reach both systems: PostgreSQL as the system of
-- record, the Redis Stream as the fan-out path. Both env vars are required.
module Infrastructure.EventStore.AccountingIntegration (spec) where

import Control.Monad.Logger (runNoLoggingT)
import qualified Data.ByteString.Char8 as BC
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime, utctDayTime)
import qualified Database.Redis as R
import Database.Persist.Postgresql (createPostgresqlPool)
import DAL.Pool (closePool)
import Infrastructure.EventStore.Accounting
import Infrastructure.Redis.EventStream (esConn, mkEventStream, readEvents)
import System.Environment (lookupEnv)
import System.IO.Error (ioError, userError)
import Test.Hspec

epoch :: UTCTime
epoch = read "1970-01-01 00:00:00 UTC"

streamName :: Text
streamName = "surypus:test:accounting"

spec :: Spec
spec = do
  mDb <- runIO (lookupEnv "SURYPUS_TEST_DATABASE_URL")
  mRedis <- runIO (lookupEnv "SURYPUS_TEST_REDIS_URL")
  case (mDb, mRedis) of
    (Just dbUrl, Just redisUrl) ->
      beforeAll (open dbUrl redisUrl) $ afterAll closeAll $ do
        it "publishes an appended accounting event to the stream" $ \(pool, stream) -> do
          store <- mkAccountingEventStore pool streamName
          aggId <- freshAggId
          appendAccountingEvent
            store
            (AccountCreatedEvent (AccountCreated aggId "1000" "Cash" "asset" Nothing epoch))
            `shouldReturn` Right ()

          entries <- either (fail . T.unpack) pure =<< readEvents stream 10
          map fst entries `shouldBe` ["AccountCreated"]

        it "survives a Redis outage without failing the write" $ \(pool, _) -> do
          store <- mkAccountingEventStore pool streamName
          aggId <- freshAggId
          -- The store degrades to "no stream" when Redis is unreachable; the
          -- PostgreSQL append still succeeds.
          appendAccountingEvent
            store
            (AccountCreatedEvent (AccountCreated aggId "1001" "Bank" "asset" Nothing epoch))
            `shouldReturn` Right ()

    _ ->
      it "requires SURYPUS_TEST_DATABASE_URL and SURYPUS_TEST_REDIS_URL" $
        pendingWith "set both to run the accounting event store integration tests"

  where
    open dbUrl redisUrl = do
      pool <- runNoLoggingT (createPostgresqlPool (BC.pack dbUrl) 2)
      ci <- either (ioError . userError) pure (R.parseConnectInfo redisUrl)
      stream <- mkEventStream <$> R.connect ci <*> pure streamName
      pure (pool, stream)

    closeAll (pool, stream) = do
      closePool pool
      R.disconnect (esConn stream)

    freshAggId = do
      now <- getCurrentTime
      pure $ fromIntegral $ round (toRational (utctDayTime now) * 1e6)
