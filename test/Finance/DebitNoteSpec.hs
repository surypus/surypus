{-# LANGUAGE OverloadedStrings #-}

-- | QuickCheck + unit property coverage for `Finance.DebitNote`
--
-- `Finance.DebitNote` models the debit-note lifecycle: creation,
-- payment and cancellation.
--
-- Pinned invariants:
--   * `createDebitNote` applies the documented defaults
--     (issued status, no related bill, created on the given date,
--     never updated)
--   * `cancelDebitNote` always forces `DNSCancelled` and stamps the
--     update date, never touching the financial fields
--   * `payDebitNote` rejects a non-positive amount and a non-issued
--     note, otherwise marks the note `DNSPaid`
--   * a successful payment NEVER drives `dnAmount` below zero —
--     overpayment is clamped to zero (the module documents
--     \"amount must be >= 0\")
--   * `isActiveDebitNote` agrees exactly with the `DNSIssued` status
--   * `prettyDebitNote` always carries the number and the currency
--
-- Pure logic module (no DB/IO); behaviour-only spec apart from the
-- overpayment clamp pinned above.
module Finance.DebitNoteSpec (spec) where

import qualified Data.Text as T
import Data.Maybe (fromMaybe, isJust)
import Data.Time.Calendar (Day, fromGregorian)
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, choose, elements, forAll)

import Finance.DebitNote

-- | Deterministic day generator (bounds keep the day valid).
genDay :: Gen Day
genDay = do
  y <- choose (2000, 2030)
  m <- choose (1, 12)
  d <- choose (1, 28)
  pure $ fromGregorian y m d

-- | A debit note built through `createDebitNote`.
genNote :: Gen DebitNote
genNote = do
  day <- genDay
  amt <- choose (0, 1000000)
  pure $ createDebitNote (DebitNoteId 1) (DebitNoteNumber "DN-001") day amt (CurrencyCode "RUB") "reason"

-- | A note with an arbitrary status (to probe the status guards).
genNoteWithStatus :: Gen DebitNote
genNoteWithStatus = do
  n <- genNote
  s <- elements [DNSIssued, DNSPaid, DNSCancelled]
  pure $ n { dnStatus = s }

-- | A fresh issued note with the given remaining amount.
mkNote :: Double -> DebitNote
mkNote amt =
  createDebitNote (DebitNoteId 1) (DebitNoteNumber "DN-1") (fromGregorian 2024 1 1) amt (CurrencyCode "RUB") "r"

spec :: Spec
spec = do
  describe "Finance.DebitNote.createDebitNote" $ do
    it "stores the fields and applies the documented defaults" $ do
      let day = fromGregorian 2024 3 15
          dn = createDebitNote (DebitNoteId 7) (DebitNoteNumber "DN-007") day 250.5 (CurrencyCode "USD") "overpayment"
      dnId dn `shouldBe` DebitNoteId 7
      dnNumber dn `shouldBe` DebitNoteNumber "DN-007"
      dnDate dn `shouldBe` day
      dnAmount dn `shouldBe` 250.5
      dnCurrency dn `shouldBe` CurrencyCode "USD"
      dnDescription dn `shouldBe` "overpayment"
      dnRelatedBill dn `shouldBe` Nothing
      dnStatus dn `shouldBe` DNSIssued
      dnCreatedAt dn `shouldBe` day
      dnUpdatedAt dn `shouldBe` Nothing
    prop "every created note starts issued, unrelated, unmodified and dated"
         (forAll genNote $ \dn ->
            dnStatus dn == DNSIssued
              && dnRelatedBill dn == Nothing
              && dnUpdatedAt dn == Nothing
              && dnCreatedAt dn == dnDate dn)

  describe "Finance.DebitNote.cancelDebitNote" $ do
    it "forces DNSCancelled and stamps the update date" $ do
      let c = cancelDebitNote (mkNote 100)
      dnStatus c `shouldBe` DNSCancelled
      isJust (dnUpdatedAt c) `shouldBe` True
    it "is idempotent" $ do
      let c1 = cancelDebitNote (mkNote 100)
          c2 = cancelDebitNote c1
      dnStatus c2 `shouldBe` DNSCancelled
      dnAmount c2 `shouldBe` dnAmount c1
    prop "cancellation never touches the financial fields"
         (forAll genNote $ \dn ->
            let c = cancelDebitNote dn
            in dnAmount c == dnAmount dn
                 && dnNumber c == dnNumber dn
                 && dnCurrency c == dnCurrency dn
                 && dnDescription c == dnDescription dn)
    prop "cancellation always lands on DNSCancelled"
         (forAll genNoteWithStatus $ \dn -> dnStatus (cancelDebitNote dn) == DNSCancelled)

  describe "Finance.DebitNote.payDebitNote" $ do
    it "rejects a zero or negative amount" $ do
      payDebitNote 0 (mkNote 100) `shouldBe` Nothing
      payDebitNote (-5) (mkNote 100) `shouldBe` Nothing
    it "rejects a note that is not issued" $ do
      payDebitNote 10 ((mkNote 100) { dnStatus = DNSPaid }) `shouldBe` Nothing
      payDebitNote 10 ((mkNote 100) { dnStatus = DNSCancelled }) `shouldBe` Nothing
    it "pays the whole amount, zeroes it and marks the note paid" $ do
      let p = fromMaybe (mkNote 100) (payDebitNote 100 (mkNote 100))
      dnAmount p `shouldBe` 0
      dnStatus p `shouldBe` DNSPaid
      isJust (dnUpdatedAt p) `shouldBe` True
    it "clamps an overpayment to zero instead of going negative" $ do
      let p = fromMaybe (mkNote 100) (payDebitNote 150 (mkNote 100))
      dnAmount p `shouldBe` 0
      dnStatus p `shouldBe` DNSPaid
    it "leaves the remainder on a partial payment" $ do
      -- Decision pinned: `payDebitNote` has no \"partially paid\" state, so a
      -- partial payment still lands on DNSPaid (see recorded follow-ups).
      let p = fromMaybe (mkNote 100) (payDebitNote 40 (mkNote 100))
      dnAmount p `shouldBe` 60
      dnStatus p `shouldBe` DNSPaid
    prop "a successful payment never makes the remaining amount negative"
         (forAll (choose (0, 1000 :: Double)) $ \amt ->
          forAll (choose (0.01, 2000 :: Double)) $ \paid ->
            let dn = mkNote amt
            in case payDebitNote paid dn of
                 Nothing -> paid <= 0 || dnStatus dn /= DNSIssued
                 Just p  -> dnAmount p >= 0)
    prop "the remainder is max 0 (amount - paid); full/over-payment zeroes it"
         (forAll (choose (0, 1000 :: Double)) $ \amt ->
          forAll (choose (0.01, 2000 :: Double)) $ \paid ->
            let dn = mkNote amt
            in case payDebitNote paid dn of
                 Nothing -> False
                 Just p  -> dnAmount p == max 0 (amt - paid))

  describe "Finance.DebitNote status predicates" $ do
    it "isActiveDebitNote is true exactly for DNSIssued" $
      map (\s -> isActiveDebitNote ((mkNote 1) { dnStatus = s }))
          [DNSIssued, DNSPaid, DNSCancelled]
        `shouldBe` [True, False, False]

  describe "Finance.DebitNote.prettyDebitNote" $ do
    it "renders the number, amount and currency" $
      prettyDebitNote (mkNote 99.5)
        { dnNumber = DebitNoteNumber "DN-42", dnCurrency = CurrencyCode "EUR" }
          `shouldBe` "DN-42 - 99.5 EUR"
    prop "always contains the note number and the currency"
         (forAll genNote $ \dn ->
            T.isInfixOf (unDebitNoteNumber (dnNumber dn)) (prettyDebitNote dn)
              && T.isInfixOf (unCurrencyCode (dnCurrency dn)) (prettyDebitNote dn))
