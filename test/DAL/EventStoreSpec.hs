{-# LANGUAGE OverloadedStrings #-}

module DAL.EventStoreSpec where

import DAL.EventStore
import Data.Aeson (Value (..))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
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
  }

spec :: ConnectionPool -> Spec
spec pool = do
  describe "DAL.EventStore" $ do
    it "can append and retrieve events" $ do
      let aggId = 1001 :: Int64
          aggType = "test-aggregate" :: Text
          ev = mkEvent aggId aggType "TestEvent" 1 1 (String "test-data")

      res1 <- appendEvent pool ev
      res1 `shouldBe` Right ()

      res2 <- getEvents pool aggId aggType
      case res2 of
        Left err -> expectationFailure $ T.unpack err
        Right events -> do
          length events `shouldSatisfy` (> 0)
          let e = head events
          eventAggregateId e `shouldBe` aggId
          eventAggregateType e `shouldBe` aggType
          eventEventType e `shouldBe` "TestEvent"
          eventSequenceNumber e `shouldBe` 1

    it "can get events starting from a sequence number" $ do
      let aggId = 1002 :: Int64
          aggType = "test-aggregate" :: Text

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

    it "can get latest sequence number" $ do
      let aggId = 1003 :: Int64
          aggType = "test-aggregate" :: Text

      _ <- appendEvent pool (mkEvent aggId aggType "Event1" 1 1 (String "data1"))
      _ <- appendEvent pool (mkEvent aggId aggType "Event2" 1 5 (String "data2"))

      res <- getLatestSequence pool aggId aggType
      res `shouldBe` Right (Just 5)

    it "returns Nothing for latest sequence when no events exist" $ do
      res <- getLatestSequence pool 9999 "non-existent"
      res `shouldBe` Right Nothing
