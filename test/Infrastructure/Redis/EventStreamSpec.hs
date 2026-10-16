{-# LANGUAGE OverloadedStrings #-}

-- | Tests for the Redis Streams fan-out path.
--
-- The pure helpers are covered unconditionally; the live round-trip needs a
-- Redis server and is skipped unless @SURYPUS_TEST_REDIS_URL@ is set.
module Infrastructure.Redis.EventStreamSpec (spec) where

import Data.Aeson (Value (..), object, (.=))
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (getCurrentTime)
import qualified Database.Redis as R
import Infrastructure.Redis.EventStream
import System.Environment (lookupEnv)
import System.IO.Error (ioError, userError)
import Test.Hspec

spec :: Spec
spec = do
  describe "defaultStreamName" $ do
    it "is namespaced under the application prefix" $
      defaultStreamName `shouldSatisfy` ("surypus:events" `T.isPrefixOf`)

  describe "encodeEvent/decodeEvent" $ do
    it "round-trips a JSON value" $
      decodeEvent (encodeEvent payload) `shouldBe` Just payload

    it "round-trips an object with several fields" $
      decodeEvent (encodeEvent (object ["a" .= (1 :: Int), "b" .= ("x" :: Text)]))
        `shouldBe` Just (object ["a" .= (1 :: Int), "b" .= ("x" :: Text)])

    it "rejects a non-JSON payload" $
      decodeEvent "not json" `shouldBe` (Nothing :: Maybe Value)

  describe "live stream" $ do
    mUrl <- runIO (lookupEnv "SURYPUS_TEST_REDIS_URL")
    case mUrl of
      Nothing ->
        it "requires SURYPUS_TEST_REDIS_URL" $
          pendingWith "set SURYPUS_TEST_REDIS_URL=redis://localhost:6379 to test the live stream"
      Just url ->
        beforeAll (connectStream url) $ afterAll (R.disconnect . esConn) $ do
          it "reports zero length on a fresh stream" $ \stream ->
            streamLength stream `shouldReturn` Right 0

          it "publishes an event that reads back unchanged" $ \stream -> do
            publishEvent stream "AccountCreated" payload `shouldReturn` Right ()
            streamLength stream `shouldReturn` Right 1
            readEvents stream 10 `shouldReturn` Right [("AccountCreated", payload)]

          it "keeps the eventType separate from the body" $ \stream -> do
            publishEvent stream "JournalEntryPosted" (Number 42) `shouldReturn` Right ()
            entries <- either (fail . T.unpack) pure =<< readEvents stream 10
            lookup "JournalEntryPosted" entries `shouldBe` Just (Number 42)

          it "reads oldest first" $ \stream -> do
            entries <- either (fail . T.unpack) pure =<< readEvents stream 10
            map fst entries `shouldBe` ["AccountCreated", "JournalEntryPosted"]

  where
    payload = object ["accountId" .= (7 :: Int), "code" .= ("401" :: Text)]

    -- | A per-run stream name so repeated runs do not read each other's entries.
    connectStream url = do
      ci <- either (ioError . userError) pure (R.parseConnectInfo url)
      conn <- R.connect ci
      now <- getCurrentTime
      pure (mkEventStream conn ("surypus:test:events:" <> T.pack (show now)))
