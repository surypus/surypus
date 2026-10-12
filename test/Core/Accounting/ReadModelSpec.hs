-- | Tests for the JSON-based accounting read-model replay layer
-- ('Core.Accounting.ReadModel'). The layer is pure: events are plain
-- 'ES.Event' records, so the producer/consumer contract can be pinned
-- without a database.
{-# LANGUAGE OverloadedStrings #-}

module Core.Accounting.ReadModelSpec (spec) where

import Core.Accounting.ReadModel
import Data.Aeson (Value, object, toJSON, (.=))
import Data.Int (Int64)
import Data.Time (UTCTime (..), fromGregorian)
import Infrastructure.EventStore.Accounting
  ( AccountingEvent (..),
    JournalEntryPosted (..),
  )
import qualified DAL.EventStore as ES
import Test.Hspec

ts :: UTCTime
ts = UTCTime (fromGregorian 2026 1 1) 0

-- | An event row as it would come back from the event store, typed as
-- @JournalEntryPosted@ (the only type 'applyEvent' dispatches here).
mkEvent :: Value -> ES.Event
mkEvent payload = ES.Event
  { ES.eventAggregateId = 42,
    ES.eventAggregateType = "journal_entry",
    ES.eventEventType = "JournalEntryPosted",
    ES.eventEventVersion = 1,
    ES.eventSchemaVersion = 1,
    ES.eventEventData = payload,
    ES.eventEventMetadata = Nothing,
    ES.eventSequenceNumber = 1,
    ES.eventOccurredAt = ts,
    ES.eventCreatedAt = ts
  }

-- | Exactly the payload the real producer writes:
-- 'Infrastructure.EventStore.Accounting.appendAccountingEvent' stores
-- @toJSON (JournalEntryPostedEvent ev)@ — a tagged union whose fields sit
-- under "contents" with the record field names as keys.
producerPayload :: Int64 -> Int64 -> Int64 -> Double -> Value
producerPayload entryId debitAcc creditAcc amount =
  toJSON $
    JournalEntryPostedEvent
      JournalEntryPosted
        { jepEntryId = entryId,
          jepDebitAcc = debitAcc,
          jepCreditAcc = creditAcc,
          jepAmount = amount,
          jepCurrency = "RUB",
          jepDescription = "test entry",
          jepDate = fromGregorian 2026 1 1,
          jepTimestamp = ts
        }

-- | A read model for one account with a zero starting balance.
modelFor :: Int64 -> AccountReadModel
modelFor accountId =
  AccountReadModel
    { armAccountId = accountId,
      armCode = Just "51",
      armName = Just "Test account",
      armAccountType = Just 1,
      armCurrencyId = Just 1,
      armBalanceState =
        BalanceState
          { bsAccountId = accountId,
            bsCurrentBalance = 0.0,
            bsDebitTotal = 0.0,
            bsCreditTotal = 0.0,
            bsLastUpdated = ts,
            bsEventCount = 0
          },
      armCreatedAt = ts,
      armUpdatedAt = ts
    }

spec :: Spec
spec = describe "Core.Accounting.ReadModel JSON replay" $ do
  it "posts a debit when replaying a real producer event" $ do
    let model = applyJournalEntryPosted (modelFor 100) (mkEvent (producerPayload 42 100 200 1500.0))
    bsCurrentBalance (armBalanceState model) `shouldBe` 1500.0
    bsDebitTotal (armBalanceState model) `shouldBe` 1500.0
    bsCreditTotal (armBalanceState model) `shouldBe` 0.0
    bsEventCount (armBalanceState model) `shouldBe` 1

  it "posts a credit when replaying a real producer event" $ do
    let model = applyJournalEntryPosted (modelFor 200) (mkEvent (producerPayload 42 100 200 1500.0))
    bsCurrentBalance (armBalanceState model) `shouldBe` (-1500.0)
    bsCreditTotal (armBalanceState model) `shouldBe` 1500.0
    bsDebitTotal (armBalanceState model) `shouldBe` 0.0

  it "leaves a bystander account untouched" $ do
    let model = applyJournalEntryPosted (modelFor 999) (mkEvent (producerPayload 42 100 200 1500.0))
    bsCurrentBalance (armBalanceState model) `shouldBe` 0.0
    bsDebitTotal (armBalanceState model) `shouldBe` 0.0
    bsCreditTotal (armBalanceState model) `shouldBe` 0.0

  it "dispatches JournalEntryPosted events through applyEvent" $ do
    let model = applyEvent (modelFor 100) (mkEvent (producerPayload 42 100 200 1500.0))
    bsCurrentBalance (armBalanceState model) `shouldBe` 1500.0

  it "accumulates multiple entries on the same account" $ do
    let e1 = mkEvent (producerPayload 42 100 200 500.0)
        e2 = mkEvent (producerPayload 43 100 200 250.0)
        model = applyJournalEntryPosted (applyJournalEntryPosted (modelFor 100) e1) e2
    bsCurrentBalance (armBalanceState model) `shouldBe` 750.0
    bsEventCount (armBalanceState model) `shouldBe` 2

  it "conserves double-entry across debit and credit accounts" $ do
    let payload = producerPayload 42 100 200 1500.0
        debit = applyJournalEntryPosted (modelFor 100) (mkEvent payload)
        credit = applyJournalEntryPosted (modelFor 200) (mkEvent payload)
    bsCurrentBalance (armBalanceState debit) `shouldBe` 1500.0
    bsCurrentBalance (armBalanceState credit) `shouldBe` (-1500.0)
    bsCurrentBalance (armBalanceState debit) + bsCurrentBalance (armBalanceState credit) `shouldBe` 0.0

  it "still applies legacy changeAmount payloads" $ do
    let legacy = mkEvent (object ["changeAmount" .= (250.0 :: Double)])
        model = applyJournalEntryPosted (modelFor 100) legacy
    bsCurrentBalance (armBalanceState model) `shouldBe` 250.0
    bsDebitTotal (armBalanceState model) `shouldBe` 250.0

  it "applies zero change for events with no amount keys" $ do
    let model = applyJournalEntryPosted (modelFor 100) (mkEvent (object []))
    bsCurrentBalance (armBalanceState model) `shouldBe` 0.0
    bsEventCount (armBalanceState model) `shouldBe` 1

  it "ignores events whose payload is not an object" $ do
    let model = applyJournalEntryPosted (modelFor 100) (mkEvent (toJSON (42 :: Int)))
    bsCurrentBalance (armBalanceState model) `shouldBe` 0.0
