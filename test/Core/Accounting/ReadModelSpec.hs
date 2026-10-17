-- | Tests for the JSON-based accounting read-model replay layer
-- ('Core.Accounting.ReadModel'). The layer is pure: events are plain
-- 'ES.Event' records, so the producer/consumer contract can be pinned
-- without a database.
{-# LANGUAGE OverloadedStrings #-}

module Core.Accounting.ReadModelSpec (spec) where

import Core.Accounting.ReadModel
import Data.Aeson (Value, object, toJSON, (.=))
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime (..), fromGregorian)
import Infrastructure.EventStore.Accounting
  ( AccountingEvent (..),
    AccountCreated (..),
    JournalEntryPosted (..),
  )
import qualified DAL.EventStore as ES
import Test.Hspec

ts :: UTCTime
ts = UTCTime (fromGregorian 2026 1 1) 0

-- | An event row as it would come back from the event store, typed as
-- @JournalEntryPosted@ (one of the types 'applyEvent' dispatches here).
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
      armAccountType = Just "asset",
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

-- | Exactly the payload the real producer writes for AccountCreated:
-- 'Infrastructure.EventStore.Accounting.appendAccountingEvent' stores
-- @toJSON (AccountCreatedEvent ev)@ — a tagged union whose fields sit under
-- "contents" with the record field names as keys.
producerAccountCreated :: Int64 -> Text -> Text -> Value
producerAccountCreated accountId code name =
  toJSON $
    AccountCreatedEvent
      AccountCreated
        { acAccountId = accountId,
          acCode = code,
          acName = name,
          acType = "asset",
          acParentId = Nothing,
          acTimestamp = ts
        }

-- | An event row as it would come back from the event store, typed as
-- @AccountCreated@. The real producer stores the account id as the aggregate
-- id ('Infrastructure.EventStore.Accounting.getEventInfo' returns
-- @(acAccountId ev, \"account\", \"AccountCreated\")@).
mkCreatedEvent :: Int64 -> Value -> ES.Event
mkCreatedEvent accountId payload = (mkEvent payload)
  { ES.eventAggregateId = accountId,
    ES.eventAggregateType = "account",
    ES.eventEventType = "AccountCreated"
  }

-- | An event row typed as @BalanceAdjusted@. No producer writes this
-- variant yet ('Infrastructure.EventStore.Accounting.AccountingEvent' has no
-- such constructor) — these tests pin the documented contract a future
-- writer must follow.
mkBalanceEvent :: Value -> ES.Event
mkBalanceEvent payload = (mkEvent payload)
  { ES.eventEventType = "BalanceAdjusted"
  }

-- | A model whose balance already carries prior movement, so relative
-- adjustments are distinguishable from absolute ones.
modelWithBalance :: Int64 -> Double -> AccountReadModel
modelWithBalance accountId bal = (modelFor accountId)
  { armBalanceState = (armBalanceState (modelFor accountId))
      { bsCurrentBalance = bal
      , bsDebitTotal = 500.0
      }
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

  it "applies code and name from a real AccountCreated producer event" $ do
    let model = applyAccountCreated (modelFor 100)
                  (mkCreatedEvent 100 (producerAccountCreated 100 "51" "Расчетный счет"))
    armCode model `shouldBe` Just "51"
    armName model `shouldBe` Just "Расчетный счет"

  it "resets balance state and stamp on AccountCreated" $ do
    let model = applyAccountCreated (modelFor 100)
                  (mkCreatedEvent 100 (producerAccountCreated 100 "51" "Cash"))
    armAccountId model `shouldBe` 100
    bsCurrentBalance (armBalanceState model) `shouldBe` 0.0
    bsDebitTotal (armBalanceState model) `shouldBe` 0.0
    bsCreditTotal (armBalanceState model) `shouldBe` 0.0
    bsEventCount (armBalanceState model) `shouldBe` 1
    armCreatedAt model `shouldBe` ts
    armUpdatedAt model `shouldBe` ts

  it "dispatches AccountCreated events through applyEvent" $ do
    let model = applyEvent (modelFor 100)
                  (mkCreatedEvent 100 (producerAccountCreated 100 "91" "Other income"))
    armCode model `shouldBe` Just "91"
    armName model `shouldBe` Just "Other income"
    bsEventCount (armBalanceState model) `shouldBe` 1

  it "still applies legacy flat AccountCreated payloads" $ do
    let legacy = mkCreatedEvent 100 (object ["acCode" .= ("51" :: Text), "acName" .= ("Cash" :: Text)])
        model = applyAccountCreated (modelFor 100) legacy
    armCode model `shouldBe` Just "51"
    armName model `shouldBe` Just "Cash"

  it "leaves code and name as Nothing for AccountCreated payloads with no identity keys" $ do
    let model = applyAccountCreated (modelFor 100) (mkCreatedEvent 100 (object []))
    armCode model `shouldBe` Nothing
    armName model `shouldBe` Nothing

  it "keeps the producer's Text account type" $ do
    -- account_type is a TEXT column and the producer writes acType as the same
    -- Text category, so the read model carries it through rather than mapping it
    -- to a non-existent Int id (which used to be discarded as Nothing).
    let model = applyAccountCreated (modelFor 100)
                  (mkCreatedEvent 100 (producerAccountCreated 100 "01" "Fixed assets"))
    armAccountType model `shouldBe` Just "asset"
    armCurrencyId model `shouldBe` Nothing

  it "applies a changeAmount BalanceAdjusted relative to the old balance" $ do
    -- changeAmount is a delta on the existing balance, not an absolute set:
    -- a payload without newBalance must never zero a live balance.
    let model = applyBalanceAdjusted (modelWithBalance 100 400.0)
                  (mkBalanceEvent (object ["changeAmount" .= (250.0 :: Double)]))
    bsCurrentBalance (armBalanceState model) `shouldBe` 650.0
    bsDebitTotal (armBalanceState model) `shouldBe` 750.0
    bsCreditTotal (armBalanceState model) `shouldBe` 0.0
    bsEventCount (armBalanceState model) `shouldBe` 1

  it "applies a negative changeAmount BalanceAdjusted to the credit total" $ do
    let model = applyBalanceAdjusted (modelWithBalance 100 400.0)
                  (mkBalanceEvent (object ["changeAmount" .= (-100.0 :: Double)]))
    bsCurrentBalance (armBalanceState model) `shouldBe` 300.0
    bsCreditTotal (armBalanceState model) `shouldBe` 100.0
    bsDebitTotal (armBalanceState model) `shouldBe` 500.0

  it "sets the balance absolutely from a newBalance BalanceAdjusted" $ do
    let model = applyBalanceAdjusted (modelWithBalance 100 400.0)
                  (mkBalanceEvent (object ["newBalance" .= (700.0 :: Double)]))
    bsCurrentBalance (armBalanceState model) `shouldBe` 700.0
    bsDebitTotal (armBalanceState model) `shouldBe` 500.0

  it "lets newBalance override changeAmount for the current balance" $ do
    let model = applyBalanceAdjusted (modelWithBalance 100 400.0)
                  (mkBalanceEvent (object ["changeAmount" .= (250.0 :: Double)
                                          , "newBalance" .= (700.0 :: Double)]))
    bsCurrentBalance (armBalanceState model) `shouldBe` 700.0
    bsDebitTotal (armBalanceState model) `shouldBe` 750.0

  it "applies a tagged-union BalanceAdjusted payload" $ do
    -- Same shape the real producer would write for any event variant:
    -- fields under "contents", unwrapped like the other appliers.
    let payload = object ["tag" .= ("BalanceAdjusted" :: Text)
                         , "contents" .= object ["changeAmount" .= (100.0 :: Double)]]
        model = applyBalanceAdjusted (modelWithBalance 100 400.0) (mkBalanceEvent payload)
    bsCurrentBalance (armBalanceState model) `shouldBe` 500.0

  it "applies zero change for BalanceAdjusted payloads with no adjustment keys" $ do
    let model = applyBalanceAdjusted (modelWithBalance 100 300.0) (mkBalanceEvent (object []))
    bsCurrentBalance (armBalanceState model) `shouldBe` 300.0
    bsDebitTotal (armBalanceState model) `shouldBe` 500.0
    bsEventCount (armBalanceState model) `shouldBe` 1
    bsLastUpdated (armBalanceState model) `shouldBe` ts

  it "dispatches BalanceAdjusted events through applyEvent" $ do
    let model = applyEvent (modelWithBalance 100 400.0)
                  (mkBalanceEvent (object ["changeAmount" .= (250.0 :: Double)]))
    bsCurrentBalance (armBalanceState model) `shouldBe` 650.0
