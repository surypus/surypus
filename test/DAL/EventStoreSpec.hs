{-# LANGUAGE OverloadedStrings #-}

module DAL.EventStoreSpec (spec) where

import DAL.EventStore
import Data.Aeson (Value (..))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, diffUTCTime, getCurrentTime, utctDayTime)
import DAL.Pool (ConnectionPool)
import Test.Hspec

mkEvent :: Int64 -> Text -> Text -> Int -> Int64 -> Value -> Event
mkEvent aggId aggType eventType ver seqNum payload = Event
  { eventAggregateId    = aggId
  , eventAggregateType  = aggType
  , eventEventType      = eventType
  , eventEventVersion   = ver
  , eventSchemaVersion  = 1
  , eventEventData      = payload
  , eventEventMetadata  = Nothing
  , eventSequenceNumber = seqNum
  , eventOccurredAt     = epoch
  , eventCreatedAt      = epoch
  }

epoch :: UTCTime
epoch = read "1970-01-01 00:00:00 UTC"

-- | A per-run aggregate id, so repeated runs against the same database do not
-- accumulate events under one aggregate.
freshAggId :: IO Int64
freshAggId = do
  now <- getCurrentTime
  pure $ fromIntegral $ round (toRational (utctDayTime now) * 1e6)

-- | The event store round-trip needs a live PostgreSQL, so this spec is run
-- through "DAL.EventStoreIntegration", which supplies the pool.
spec :: SpecWith ConnectionPool
spec = do
  describe "DAL.EventStore" $ do
    it "can append and retrieve events" $ \pool -> do
      aggId <- freshAggId
      let aggType = "test-aggregate" :: Text
          ev = mkEvent aggId aggType "TestEvent" 1 1 (String "test-data")

      appendEvent pool ev `shouldReturn` Right ()

      res2 <- getEvents pool aggId aggType
      case res2 of
        Left err -> expectationFailure $ T.unpack err
        Right events -> do
          length events `shouldBe` 1
          let e = head events
          eventAggregateId e `shouldBe` aggId
          eventAggregateType e `shouldBe` aggType
          eventEventType e `shouldBe` "TestEvent"
          eventSequenceNumber e `shouldBe` 1
          eventEventData e `shouldBe` String "test-data"

    it "can get events starting from a sequence number" $ \pool -> do
      aggId <- freshAggId
      let aggType = "test-aggregate" :: Text

      _ <- appendEvent pool (mkEvent aggId aggType "Event1" 1 1 (String "data1"))
      _ <- appendEvent pool (mkEvent aggId aggType "Event2" 1 2 (String "data2"))
      _ <- appendEvent pool (mkEvent aggId aggType "Event3" 1 3 (String "data3"))

      res <- getEventsFrom pool aggId aggType 2
      case res of
        Left err -> expectationFailure $ T.unpack err
        Right events -> do
          length events `shouldBe` 2
          eventSequenceNumber (head events) `shouldBe` 2
          eventSequenceNumber (events !! 1) `shouldBe` 3

    it "can get latest sequence number" $ \pool -> do
      aggId <- freshAggId
      let aggType = "test-aggregate" :: Text

      _ <- appendEvent pool (mkEvent aggId aggType "Event1" 1 1 (String "data1"))
      _ <- appendEvent pool (mkEvent aggId aggType "Event2" 1 5 (String "data2"))

      getLatestSequence pool aggId aggType `shouldReturn` Right (Just 5)

    it "returns Nothing for latest sequence when no events exist" $ \pool -> do
      aggId <- freshAggId
      getLatestSequence pool aggId "non-existent" `shouldReturn` Right Nothing

    it "round-trips a snapshot and replays only the events after it" $ \pool -> do
      aggId <- freshAggId
      let aggType = "test-snapshot" :: Text

      _ <- appendEvent pool (mkEvent aggId aggType "Event1" 1 1 (String "data1"))
      _ <- appendEvent pool (mkEvent aggId aggType "Event2" 1 2 (String "data2"))

      now <- getCurrentTime
      saveSnapshot pool
        Snapshot
          { snapAggregateId = aggId
          , snapAggregateType = aggType
          , snapVersion = 1
          , snapLastSeq = 2
          , snapData = "{}"
          , snapCreatedAt = now
          }
        `shouldReturn` Right ()

      mSnap <- getLatestSnapshot pool aggId aggType
      case mSnap of
        Left err -> expectationFailure (T.unpack err)
        Right Nothing -> expectationFailure "snapshot was not stored"
        Right (Just snap) -> do
          snapAggregateId snap `shouldBe` aggId
          snapAggregateType snap `shouldBe` aggType
          snapVersion snap `shouldBe` 1
          snapLastSeq snap `shouldBe` 2
          snapData snap `shouldBe` "{}"
          -- PostgreSQL stores microseconds, so allow for the truncation
          abs (diffUTCTime (snapCreatedAt snap) now) `shouldSatisfy` (< 1)

      replayFromSnapshot pool aggId aggType `shouldReturn` Right []
