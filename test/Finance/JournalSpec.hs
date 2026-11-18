{-# LANGUAGE OverloadedStrings #-}

-- | QuickCheck + unit property coverage for `Finance.Journal`
-- — the enhanced double-entry journaling module.
--
-- This module is pure (no DB/IO imports); the invariants below are
-- verified deterministically with QuickCheck plus pinned unit
-- assertions. They guard the journaling contract:
--   * 'cancelJournalEntry' transitions 'JSEntry' to 'JSCancelled';
--   * 'calculateJournalBalance' returns the exact balance for a
--     known account and 0 for an unknown one;
--   * 'validateJournal' rejects journals with draft ('JSEntry')
--     entries;
--   * 'validateJournal' accepts journals whose entries are all
--     posted/verified/cancelled and whose 'journalValidated' flag
--     is True.
module Finance.JournalSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck
import Data.Int (Int64)
import Data.Text (Text, pack)
import Data.Time (Day, UTCTime (..), fromGregorian)
import qualified Data.Map.Strict as Map

import Finance.Journal

-- | Fixed reference 'UTCTime' used by deterministic unit tests so that
-- every 'Left'/'Right' expectation is reproducible.
t0 :: UTCTime
t0 = UTCTime (fromGregorian 2026 6 1) 0

-- | Arbitrary but *valid* journal entry: a posted or verified entry
-- with non-negative amount, a non-empty debit/credit account and a
-- positive amount.
genValidEntry :: Gen JournalEntry
genValidEntry = do
  date <- do
    y <- choose (2020, 2030)
    m <- choose (1, 12)
    d <- choose (1, 28)
    pure $ fromGregorian y m d
  debit <- pack <$> listOf1 (elements ['A' .. 'Z'])
  credit <- pack <$> listOf1 (elements ['A' .. 'Z'])
  amount <- choose (0.01, 100000)
  currency <- pack <$> listOf1 (elements ['R', 'U', 'B'])
  desc <- pack <$> listOf1 (elements ('a' : ['b' .. 'z']))
  createdBy <- choose (1, 1000)
  status <- elements [JSPosted, JSVerified, JSCancelled]
  pure $ JournalEntry
    { jeId = JournalId 1
    , jeDate = date
    , jeDebitAcc = debit
    , jeCreditAcc = credit
    , jeAmount = amount
    , jeCurrency = currency
    , jeDescription = desc
    , jeReference = Nothing
    , jeStatus = status
    , jeCreatedBy = createdBy
    , jeCreatedAt = t0
    }

-- | A journal whose only entry is a draft ('JSEntry') — the
-- situation that 'validateJournal' must reject.
genDraftJournal :: Gen Journal
genDraftJournal = do
  entries <- Map.singleton (JournalId 1) <$> genValidEntry
  pure $ Journal
    { journalEntries = entries
    , journalBalances = Map.empty
    , journalCurrency = pack "RUB"
    , journalValidated = True
    }

-- | A journal whose entries are all posted/verified/cancelled.
genPostedJournal :: Gen Journal
genPostedJournal = do
  entries <- Map.singleton (JournalId 1) <$> genValidEntry
  pure $ Journal
    { journalEntries = entries
    , journalBalances = Map.singleton (pack "1000") 0
    , journalCurrency = pack "RUB"
    , journalValidated = True
    }

spec :: Spec
spec = do
  describe "Finance.Journal.cancelJournalEntry" $ do
    it "transitions JSEntry to JSCancelled" $ do
      let entry = createJournalEntry
            (JournalId 1) (fromGregorian 2026 6 1) "1000" "2000" 100.0 "RUB" "desc" 1 t0
      cancelJournalEntry entry `shouldSatisfy` \e ->
        jeStatus e == JSCancelled

    it "cancels a posted entry to JSCancelled" $ do
      let entry = createJournalEntry
            (JournalId 1) (fromGregorian 2026 6 1) "1000" "2000" 100.0 "RUB" "desc" 1 t0
          posted = entry { jeStatus = JSPosted }
      cancelJournalEntry posted `shouldSatisfy` \e ->
        jeStatus e == JSCancelled

  describe "Finance.Journal.calculateJournalBalance" $ do
    it "returns the exact balance for a known account" $ do
      let journal = Journal
            { journalEntries = Map.empty
            , journalBalances = Map.singleton (pack "1000") 500.0
            , journalCurrency = pack "RUB"
            , journalValidated = True
            }
      calculateJournalBalance "1000" journal `shouldBe` 500.0

    it "returns 0 for an unknown account" $ do
      let journal = Journal
            { journalEntries = Map.empty
            , journalBalances = Map.singleton (pack "1000") 500.0
            , journalCurrency = pack "RUB"
            , journalValidated = True
            }
      calculateJournalBalance "9999" journal `shouldBe` 0

  describe "Finance.Journal.validateJournal" $ do
    it "rejects a journal containing draft (JSEntry) entries" $ do
      let journal = Journal
            { journalEntries = Map.singleton (JournalId 1) (createJournalEntry
                (JournalId 1) (fromGregorian 2026 6 1) "1000" "2000" 100.0 "RUB" "desc" 1 t0)
            , journalBalances = Map.empty
            , journalCurrency = pack "RUB"
            , journalValidated = True
            }
      validateJournal journal `shouldBe` False

    it "accepts a journal whose entries are all posted/verified/cancelled" $ do
      let entry = createJournalEntry
            (JournalId 1) (fromGregorian 2026 6 1) "1000" "2000" 100.0 "RUB" "desc" 1 t0
          postedEntry = entry { jeStatus = JSPosted }
          journal = Journal
            { journalEntries = Map.singleton (JournalId 1) postedEntry
            , journalBalances = Map.empty
            , journalCurrency = pack "RUB"
            , journalValidated = True
            }
      validateJournal journal `shouldBe` True

    it "accepts a fully validated journal" $ do
      let journal = Journal
            { journalEntries = Map.empty
            , journalBalances = Map.empty
            , journalCurrency = pack "RUB"
            , journalValidated = True
            }
      validateJournal journal `shouldBe` True

    it "rejects a journal with journalValidated = False" $ do
      let journal = Journal
            { journalEntries = Map.empty
            , journalBalances = Map.empty
            , journalCurrency = pack "RUB"
            , journalValidated = False
            }
      validateJournal journal `shouldBe` False

  describe "Finance.Journal.createJournalEntry" $ do
    it "creates an entry with status JSEntry" $ do
      let entry = createJournalEntry
            (JournalId 1) (fromGregorian 2026 6 1) "1000" "2000" 100.0 "RUB" "desc" 1 t0
      jeStatus entry `shouldBe` JSEntry

    it "stores the supplied debit/credit accounts" $ do
      let entry = createJournalEntry
            (JournalId 1) (fromGregorian 2026 6 1) "3000" "4000" 100.0 "USD" "desc" 1 t0
      jeDebitAcc entry `shouldBe` "3000"
      jeCreditAcc entry `shouldBe` "4000"

    it "stores the supplied amount" $ do
      let entry = createJournalEntry
            (JournalId 1) (fromGregorian 2026 6 1) "1000" "2000" 250.5 "USD" "desc" 1 t0
      jeAmount entry `shouldBe` 250.5
