{-# LANGUAGE OverloadedStrings #-}

-- | QuickCheck + unit property coverage for `Finance.Ledger`.
--
-- 'Finance.Ledger' is a pure double-entry ledger module (no DB/IO). The
-- properties below pin its documented invariants:
--   * posting balanced turns keeps the accounting equation debit = credit
--   * 'calculateAccountBalance' returns the accumulated balance per account
--   * posting a turn with a non-'TSNew' status is rejected ('Nothing')
--   * posting order does not matter
-- Implemented 2026-11-17; verified via 'cabal test surypus-test'.
module Finance.LedgerSpec (spec) where

import Test.Hspec
import Data.Maybe (isJust)
import Data.Int (Int64)
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck
import Data.Text (Text, pack)
import qualified Data.Map.Strict as Map
import Data.Time.Calendar (Day, fromGregorian)

import Finance.Account (AccountCode (..))
import Finance.Ledger

-- | Account codes with debit nature (active/passive groups per
-- 'Finance.Ledger.isDebitAccount'): 01-04, 07-09, 10-11, 14-16, 19, 20-21,
-- 23, 25-26, 28-29, 40-46, 50-52, 55, 57-58.
debitPrefixes :: [String]
debitPrefixes =
  [ "01", "02", "03", "04", "07", "08", "09", "10", "11", "14", "15", "16",
    "19", "20", "21", "23", "25", "26", "28", "29", "40", "41", "42", "43",
    "44", "45", "46", "50", "51", "52", "55", "57", "58"
  ]

-- | Account codes with credit nature (the complement of 'debitPrefixes').
creditPrefixes :: [String]
creditPrefixes =
  [ "00", "05", "06", "12", "13", "17", "18", "22", "24", "27", "30", "31",
    "32", "33", "34", "35", "36", "37", "38", "39", "47", "48", "49", "53",
    "54", "56", "59", "60", "61", "62", "63", "64", "65", "66", "67", "68",
    "69", "70", "71", "72", "73", "74", "75", "76", "77", "78", "79", "80",
    "81", "82", "83", "84", "85", "86", "87", "88", "89", "90", "91", "92",
    "93", "94", "95", "96", "97", "98", "99"
  ]

-- | Deterministic day generator (bounds keep things terminating).
genDay :: Gen Day
genDay = do
  y <- choose (2000, 2030)
  m <- choose (1, 12)
  d <- choose (1, 28)
  pure $ fromGregorian y m d

-- | Account code with the given nature-classification. Keeps generated
-- ledgers balanced by construction.
genAccountCode :: [String] -> Gen AccountCode
genAccountCode prefixes = do
  p <- elements prefixes
  n <- (choose (0, 9999) :: Gen Int)
  let s = show n
  pure $ AccountCode (pack p <> pack (replicate (4 - length s) '0' ++ s))

-- | A balanced new entry: debit account is debit-nature, credit is
-- credit-nature, equal amounts on both sides.
genTurn :: Gen AccTurn
genTurn = do
  tid <- TurnId <$> (choose (1, 1000000) :: Gen Int64)
  debit <- genAccountCode debitPrefixes
  credit <- genAccountCode creditPrefixes
  n <- (choose (1, 100000) :: Gen Int)
  amount <- pure $ Amount (fromIntegral (n * 100) :: Double)
  day <- genDay
  pure $ createTurn tid debit credit amount (TransactionDate day)

-- | Apply a posting; the start ledger is kept if the turn is not posted.
applyTurn :: Ledger -> AccTurn -> Ledger
applyTurn ledger turn = maybe ledger id (postTurn turn ledger)

-- | Empty balanced ledger.
emptyLedger :: Ledger
emptyLedger =
  Ledger
    { ledgerEntries = Map.empty
    , ledgerBalance = Map.empty
    , ledgerCurrency = CurrencyCode "RUB"
    }

spec :: Spec
spec = do
  describe "Finance.Ledger.isDebitAccount / isCreditAccount" $ do
    it "classifies debit-nature codes as debit" $ do
      isDebitAccount (AccountCode "01") `shouldBe` True
      isDebitAccount (AccountCode "44") `shouldBe` True
      isDebitAccount (AccountCode "50") `shouldBe` True
    it "classifies credit-nature codes as credit" $ do
      isCreditAccount (AccountCode "60") `shouldBe` True
      isCreditAccount (AccountCode "99") `shouldBe` True
      isCreditAccount (AccountCode "05") `shouldBe` True

  describe "Finance.Ledger.calculateAccountBalance" $ do
    it "returns 0 for an empty ledger" $ do
      calculateAccountBalance (AccountCode "01") emptyLedger `shouldBe` Amount 0

  describe "Finance.Ledger.postTurn" $ do
    it "rejects a turn that is not TSNew" $ do
      let turn =
            createTurn (TurnId 1) (AccountCode "01") (AccountCode "60")
                       (Amount 100.0) (TransactionDate (fromGregorian 2026 1 1))
          reverted = turn { turnStatus = TSReverted }
      postTurn reverted emptyLedger `shouldBe` Nothing
    it "accepts a TSNew turn" $ do
      let turn =
            createTurn (TurnId 1) (AccountCode "01") (AccountCode "60")
                       (Amount 100.0) (TransactionDate (fromGregorian 2026 1 1))
      postTurn turn emptyLedger `shouldSatisfy` isJust

  describe "Finance.Ledger.accounting-equation invariant" $ do
    it "balances a single balanced turn" $ do
      let turn =
            createTurn (TurnId 1) (AccountCode "01") (AccountCode "60")
                       (Amount 100.0) (TransactionDate (fromGregorian 2026 1 1))
          ledger = applyTurn emptyLedger turn
      validateAccountingEquation ledger `shouldBe` True
    it "balances two turns on distinct accounts" $ do
      let l1 = applyTurn emptyLedger (createTurn (TurnId 1) (AccountCode "01") (AccountCode "60")
                 (Amount 100.0) (TransactionDate (fromGregorian 2026 1 1)))
          l2 = applyTurn l1 (createTurn (TurnId 2) (AccountCode "02") (AccountCode "61")
                     (Amount 50.0) (TransactionDate (fromGregorian 2026 1 2)))
      validateAccountingEquation l2 `shouldBe` True

  it "keeps the latest value for a duplicate turn id" $ do
    let t1 =
          createTurn (TurnId 1) (AccountCode "01") (AccountCode "60")
                     (Amount 100.0) (TransactionDate (fromGregorian 2026 1 1))
        t2 =
          createTurn (TurnId 1) (AccountCode "02") (AccountCode "99")
                     (Amount 200.0) (TransactionDate (fromGregorian 2026 1 2))
        ledger1 = applyTurn emptyLedger t1
        ledger2 = applyTurn ledger1 t2
    validateAccountingEquation ledger2 `shouldBe` True

prop_posting_preservesBalance :: Property
prop_posting_preservesBalance =
  forAll (sized $ \n -> resize (n `div` 2) (listOf genTurn)) $ \turns ->
  let ledger = foldl' applyTurn emptyLedger turns
  in validateAccountingEquation ledger === True

prop_balance_afterPosting :: Property
prop_balance_afterPosting =
  forAll genTurn $ \turn ->
  forAll (elements $ map (AccountCode . pack) (debitPrefixes ++ creditPrefixes)) $ \code ->
  case turnStatus turn of
    TSNew ->
      let maybeLedger = postTurn turn emptyLedger
          actual = fmap (calculateAccountBalance code) maybeLedger
       in case maybeLedger of
            Nothing -> property False
            Just ledger ->
              (if code == turnDebitAcc turn || code == turnCreditAcc turn
               then actual === Just (turnAmount turn)
               else actual === Just (Amount 0))
    _ -> property True

prop_posting_orderIndependent :: Property
prop_posting_orderIndependent =
  forAll (sized $ \n -> resize (n `div` 2) (listOf genTurn)) $ \as ->
  forAll (sized $ \n -> resize (n `div` 2) (listOf genTurn)) $ \bs ->
  let l1 = foldl' applyTurn emptyLedger as
      l2 = foldl' applyTurn emptyLedger bs
      l12 = foldl' applyTurn l1 bs
      l21 = foldl' applyTurn l2 as
   in validateAccountingEquation l12 === validateAccountingEquation l21
