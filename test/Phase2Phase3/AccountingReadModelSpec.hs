{-# LANGUAGE OverloadedStrings #-}

-- | Read-model rebuild for accounting: replay of the typed accounting event
-- stream (@Infrastructure.EventStore.Accounting@). Rewritten 2026-10-12 from the
-- stale in-memory @DAL.EventStore@ API (@initEventStore@ /
-- @createAccountCreatedEvent@ / @createJournalEntryEvent@, which no longer exist)
-- to the current pure replay API — no database required.
module Phase2Phase3.AccountingReadModelSpec (spec) where

import qualified Data.Map.Strict as M
import Data.Aeson (Result (..), fromJSON, toJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Calendar (Day, fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Infrastructure.EventStore.Accounting
import Test.Hspec

-- Fixed timestamps keep every assertion deterministic.
ts :: UTCTime
ts = UTCTime (fromGregorian 2024 1 15) (secondsToDiffTime 36000) -- 10:00:00 UTC

entryDate :: Day
entryDate = fromGregorian 2024 1 15

accountCreated :: Int64 -> Text -> Text -> Text -> AccountingEvent
accountCreated i code name typ =
  AccountCreatedEvent (AccountCreated i code name typ Nothing ts)

journalEntry :: Int64 -> Int64 -> Int64 -> Double -> AccountingEvent
journalEntry eid debit credit amt =
  JournalEntryPostedEvent (JournalEntryPosted eid debit credit amt "RUB" "entry" entryDate ts)

frozenEvent :: AccountingEvent
frozenEvent = AccountFrozenEvent (AccountFrozen 1 99 "audit" ts)

unfrozenEvent :: AccountingEvent
unfrozenEvent = AccountUnfrozenEvent (AccountUnfrozen 1 99 "audit" ts)

revertedEvent :: AccountingEvent
revertedEvent = EntryRevertedEvent (EntryReverted 10 11 "mistake" ts)

cancelledEvent :: AccountingEvent
cancelledEvent = EntryCancelledEvent (EntryCancelled 10 11 "mistake" ts)

-- One event of every variant, for the JSON persistence-contract roundtrip.
allEvents :: [AccountingEvent]
allEvents =
  [ accountCreated 1 "1010" "Cash" "asset"
  , journalEntry 1 1 2 1000.0
  , revertedEvent
  , cancelledEvent
  , frozenEvent
  , unfrozenEvent
  ]

spec :: Spec
spec = do
  describe "Infrastructure.EventStore.Accounting - event replay" $ do

    it "projects AccountCreated with code, name, type and zero totals" $ do
      let events = [ accountCreated 1 "1010" "Cash" "asset"
                   , accountCreated 2 "3010" "Capital" "equity" ]
          snaps = replayAccountEvents events
      case M.lookup 1 snaps of
        Just s -> do
          asCode s `shouldBe` "1010"
          asName s `shouldBe` "Cash"
          asType s `shouldBe` "asset"
          asBalance s `shouldBe` 0
          asDebitTotal s `shouldBe` 0
          asCreditTotal s `shouldBe` 0
          asEntryCount s `shouldBe` 0
          asIsFrozen s `shouldBe` False
        Nothing -> fail "account 1 not projected"
      case M.lookup 2 snaps of
        Just s -> asName s `shouldBe` "Capital"
        Nothing -> fail "account 2 not projected"

    it "moves the amount between debit and credit accounts" $ do
      let events = [ accountCreated 1 "1010" "Cash" "asset"
                   , accountCreated 2 "3010" "Capital" "equity"
                   , journalEntry 10 1 2 1000.0 ]
          snaps = replayAccountEvents events
      case (M.lookup 1 snaps, M.lookup 2 snaps) of
        (Just s1, Just s2) -> do
          asBalance s1 `shouldBe` 1000.0
          asDebitTotal s1 `shouldBe` 1000.0
          asCreditTotal s1 `shouldBe` 0
          asEntryCount s1 `shouldBe` 1
          asBalance s2 `shouldBe` (-1000.0)
          asCreditTotal s2 `shouldBe` 1000.0
          asDebitTotal s2 `shouldBe` 0
          asEntryCount s2 `shouldBe` 1
        _ -> fail "both accounts should be projected"

    it "accumulates balances across entries (double-entry conservation)" $ do
      let events = [ accountCreated 1 "1010" "Cash" "asset"
                   , accountCreated 2 "3010" "Capital" "equity"
                   , journalEntry 10 1 2 1000.0
                   , journalEntry 11 1 2 500.0
                   , journalEntry 12 2 1 200.0 ]
          snaps = replayAccountEvents events
      case M.lookup 1 snaps of
        Just s1 -> do
          asBalance s1 `shouldBe` 1300.0
          asDebitTotal s1 `shouldBe` 1500.0
          asCreditTotal s1 `shouldBe` 200.0
          asEntryCount s1 `shouldBe` 3
        Nothing -> fail "account 1 not projected"
      -- every entry touches two projected accounts, so the ledger sums to zero
      sum (map asBalance (M.elems snaps)) `shouldBe` 0

    it "reconstructAccountBalance returns the snapshot, or Nothing when unknown" $ do
      let events = [ accountCreated 1 "1010" "Cash" "asset"
                   , journalEntry 10 1 2 1000.0 ]
      case reconstructAccountBalance 1 events of
        Just s -> asBalance s `shouldBe` 1000.0
        Nothing -> fail "account 1 should be reconstructed"
      reconstructAccountBalance 999 events `shouldBe` Nothing

    it "silently skips entries touching an unprojected account" $ do
      -- account 2 is never created: M.adjust must not invent a phantom snapshot
      let events = [ accountCreated 1 "1010" "Cash" "asset"
                   , journalEntry 10 1 2 1000.0 ]
          snaps = replayAccountEvents events
      M.lookup 2 snaps `shouldBe` Nothing
      case M.lookup 1 snaps of
        Just s1 -> asBalance s1 `shouldBe` 1000.0
        Nothing -> fail "account 1 not projected"

    it "toggles asIsFrozen without touching balances" $ do
      let events = [ accountCreated 1 "1010" "Cash" "asset"
                   , journalEntry 10 1 2 1000.0
                   , frozenEvent
                   , unfrozenEvent ]
      case reconstructAccountBalance 1 (take 3 events) of
        Just s -> do
          asIsFrozen s `shouldBe` True
          asBalance s `shouldBe` 1000.0
        Nothing -> fail "account 1 not reconstructed"
      case reconstructAccountBalance 1 events of
        Just s -> asIsFrozen s `shouldBe` False
        Nothing -> fail "account 1 not reconstructed after unfreeze"

    it "treats EntryReverted and EntryCancelled as no-ops" $ do
      -- pins the current semantics: reversal events leave state untouched
      -- (a real revert/undo is a follow-up — see TASKS.md)
      let base = [ accountCreated 1 "1010" "Cash" "asset"
                 , journalEntry 10 1 2 1000.0 ]
          withReversal = base ++ [revertedEvent, cancelledEvent]
      replayAccountEvents withReversal `shouldBe` replayAccountEvents base

    it "counts one entry touching the same account twice" $ do
      -- debit == credit: two M.adjust passes, net-zero balance, count 2
      let events = [ accountCreated 1 "1010" "Cash" "asset"
                   , journalEntry 10 1 1 100.0 ]
      case reconstructAccountBalance 1 events of
        Just s -> do
          asBalance s `shouldBe` 0
          asDebitTotal s `shouldBe` 100.0
          asCreditTotal s `shouldBe` 100.0
          asEntryCount s `shouldBe` 2
        Nothing -> fail "account 1 not reconstructed"

    it "round-trips every event variant through JSON (persistence contract)" $ do
      -- appendAccountingEvent stores `toJSON event`; readAccountEvents decodes
      -- it back with fromJSON — a roundtrip failure corrupts the stream.
      mapM_ (\ev -> fromJSON (toJSON ev) `shouldBe` Success ev) allEvents
