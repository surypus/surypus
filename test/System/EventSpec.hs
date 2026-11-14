{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

-- | Unit and property-based tests for System.Event.
-- Tests the Event data type, EventType variants and logEvent function
-- including timestamp behaviour and field correctness.
module System.EventSpec (spec) where

import Data.Int (Int64)
import Data.Text (Text, pack)
import Data.Time.Clock (UTCTime (..), getCurrentTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)
import System.Event (Event (..), EventSubscription (..), EventType (..), logEvent)
import Test.Hspec
import Test.QuickCheck (Arbitrary (..), elements, vectorOf, choose, Property, property, ioProperty)

-- | Arbitrary instance for EventType used by QuickCheck properties.
instance Arbitrary EventType where
  arbitrary = elements [ETInfo, ETWarning, ETError, ETAudit]

-- | Arbitrary instance for EventSubscription used by QuickCheck properties.
instance Arbitrary EventSubscription where
  arbitrary = do
    esId <- arbitrary
    esUserId <- arbitrary
    esEventType <- arbitrary
    esWebhookId <- arbitrary
    esFlags <- arbitrary
    return $ EventSubscription esId esUserId esEventType esWebhookId esFlags

-- | Arbitrary instance for Text used by QuickCheck properties.
instance Arbitrary Text where
  arbitrary = do
    len <- choose (0, 20)
    chars <- vectorOf len (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ " -_"))
    return $ pack chars

-- | Build an EventSubscription with explicit values.
mkEventSubscription :: Int64 -> Int64 -> EventType -> Maybe Int64 -> Int -> EventSubscription
mkEventSubscription esId esUserId esEventType esWebhookId esFlags =
  EventSubscription
    { esId = esId,
      esUserId = esUserId,
      esEventType = esEventType,
      esWebhookId = esWebhookId,
      esFlags = esFlags
    }

spec :: Spec
spec = do
  describe "logEvent" logEventSpec
  describe "Event data constructor" eventSpec
  describe "EventSubscription data constructor" eventSubscriptionSpec
  describe "Properties" propertiesSpec

-------------------------------------------------------------------------------
-- logEvent
-------------------------------------------------------------------------------

logEventSpec :: Spec
logEventSpec = do
  it "creates an event with the given type, object type, object id, user id and message" $ do
    let et = ETInfo
        ot = 1
        oid = 2
        uid = 3
        msg = "test message"
    evt <- logEvent et ot oid uid msg
    evType evt `shouldBe` et
    evObjType evt `shouldBe` ot
    evObjId evt `shouldBe` oid
    evUserId evt `shouldBe` uid
    evMessage evt `shouldBe` msg

  it "assigns evId = 0 and evFlags = 0" $ do
    let et = ETAudit
        ot = 10
        oid = 20
        uid = 30
        msg = "audit event"
    evt <- logEvent et ot oid uid msg
    evId evt `shouldBe` (0 :: Int64)
    evFlags evt `shouldBe` 0

  it "assigns a non-zero POSIX timestamp" $ do
    let et = ETInfo
        ot = 1
        oid = 2
        uid = 3
        msg = "timestamp test"
    evt <- logEvent et ot oid uid msg
    let posix = realToFrac (utcTimeToPOSIXSeconds (evTime evt)) :: Double
     in posix `shouldSatisfy` (> 0)

-------------------------------------------------------------------------------
-- Event data constructor
-------------------------------------------------------------------------------

eventSpec :: Spec
eventSpec = do
  it "Event constructor produces a value with the given fields" $ do
    now <- getCurrentTime
    let evt = Event 42 ETError 100 200 300 now "custom message" 7
    evId evt `shouldBe` (42 :: Int64)
    evType evt `shouldBe` ETError
    evObjType evt `shouldBe` 100
    evObjId evt `shouldBe` 200
    evUserId evt `shouldBe` 300
    evTime evt `shouldBe` now
    evMessage evt `shouldBe` "custom message"
    evFlags evt `shouldBe` 7

-------------------------------------------------------------------------------
-- EventSubscription data constructor
-------------------------------------------------------------------------------

eventSubscriptionSpec :: Spec
eventSubscriptionSpec = do
  it "EventSubscription constructor preserves all fields" $ do
    let sub = mkEventSubscription 1 2 ETInfo (Just 3) 4
    esId sub `shouldBe` (1 :: Int64)
    esUserId sub `shouldBe` 2
    esEventType sub `shouldBe` ETInfo
    esWebhookId sub `shouldBe` Just 3
    esFlags sub `shouldBe` 4

  it "EventSubscription with Nothing webhook id" $ do
    let sub = mkEventSubscription 5 6 ETWarning Nothing 8
    esWebhookId sub `shouldBe` Nothing
    esId sub `shouldBe` (5 :: Int64)

-------------------------------------------------------------------------------
-- Properties
-------------------------------------------------------------------------------

propertiesSpec :: Spec
propertiesSpec = do
  it "logEvent: evId and evFlags are always 0" $ property prop_logEventIdAndFlagsZero
  it "logEvent: timestamp is at or after the POSIX epoch" $ property prop_logEventTimestampEpoch
  it "logEvent: all caller-supplied fields are preserved" $ property prop_logEventPreservesFields

-- | Property: logEvent always produces an event with evId = 0 and evFlags = 0.
prop_logEventIdAndFlagsZero :: EventType -> Int64 -> Int64 -> Int64 -> Text -> Property
prop_logEventIdAndFlagsZero et ot oid uid msg =
  ioProperty $ do
    evt <- logEvent et ot oid uid msg
    return $ evId evt == (0 :: Int64) && evFlags evt == 0

-- | Property: logEvent produces an event whose timestamp is non-zero and
-- is at least the POSIX epoch (1970-01-01).
prop_logEventTimestampEpoch :: EventType -> Int64 -> Int64 -> Int64 -> Text -> Property
prop_logEventTimestampEpoch et ot oid uid msg =
  ioProperty $ do
    evt <- logEvent et ot oid uid msg
    let posix = realToFrac (utcTimeToPOSIXSeconds (evTime evt)) :: Double
     in return $ posix >= 0

-- | Property: logEvent preserves all caller-supplied fields
-- (type, object type, object id, user id, message).
prop_logEventPreservesFields ::
     EventType -> Int64 -> Int64 -> Int64 -> Text -> Property
prop_logEventPreservesFields et ot oid uid msg =
  ioProperty $ do
    evt <- logEvent et ot oid uid msg
    return $
      evType evt == et
        && evObjType evt == ot
        && evObjId evt == oid
        && evUserId evt == uid
        && evMessage evt == msg
