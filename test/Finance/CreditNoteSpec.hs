{-# LANGUAGE OverloadedStrings #-}

-- | QuickCheck + unit property coverage for `Finance.CreditNote`
--
-- `Finance.CreditNote` models the credit-note lifecycle: creation,
-- cancellation and (partial or full) application.
--
-- Pinned invariants:
--   * `createCreditNote` applies the documented defaults
--     (issued status, no related bill, created on the given date,
--     never updated)
--   * `cancelCreditNote` only acts on an issued note
--   * `applyCreditNote` rejects a non-positive amount and a non-issued
--     note, otherwise reduces the remaining amount
--   * a successful application NEVER drives `cnAmount` below zero —
--     over-applying is clamped to zero and marks the note `CNSApplied`
--   * `isActiveCreditNote` / `isFullyApplied` agree exactly with the
--     `CNSIssued` / `CNSApplied` statuses
--   * `prettyCreditNote` always carries the number and the currency
--
-- Pure logic module (no DB/IO); behaviour-only spec apart from the
-- over-application clamp pinned above.
module Finance.CreditNoteSpec (spec) where

import qualified Data.Text as T
import Data.Maybe (fromMaybe, isJust, isNothing)
import Data.Time.Calendar (Day, fromGregorian)
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, choose, elements, forAll)

import Finance.CreditNote

-- | Deterministic day generator (bounds keep the day valid).
genDay :: Gen Day
genDay = do
  y <- choose (2000, 2030)
  m <- choose (1, 12)
  d <- choose (1, 28)
  pure $ fromGregorian y m d

-- | A credit note built through `createCreditNote`.
genNote :: Gen CreditNote
genNote = do
  day <- genDay
  amt <- choose (0, 1000000)
  pure $ createCreditNote (CreditNoteId 1) (CreditNoteNumber "CN-001") day amt (CurrencyCode "RUB") "reason"

-- | A note with an arbitrary status (to probe the status guards).
genNoteWithStatus :: Gen CreditNote
genNoteWithStatus = do
  n <- genNote
  s <- elements [CNSIssued, CNSCancelled, CNSApplied]
  pure $ n { cnStatus = s }

-- | A fresh issued note with the given remaining amount.
mkNote :: Double -> CreditNote
mkNote amt =
  createCreditNote (CreditNoteId 1) (CreditNoteNumber "CN-1") (fromGregorian 2024 1 1) amt (CurrencyCode "RUB") "r"

spec :: Spec
spec = do
  describe "Finance.CreditNote.createCreditNote" $ do
    it "stores the fields and applies the documented defaults" $ do
      let day = fromGregorian 2024 3 15
          cn = createCreditNote (CreditNoteId 7) (CreditNoteNumber "CN-007") day 250.5 (CurrencyCode "USD") "overpayment"
      cnId cn `shouldBe` CreditNoteId 7
      cnNumber cn `shouldBe` CreditNoteNumber "CN-007"
      cnDate cn `shouldBe` day
      cnAmount cn `shouldBe` 250.5
      cnCurrency cn `shouldBe` CurrencyCode "USD"
      cnReason cn `shouldBe` "overpayment"
      cnRelatedBill cn `shouldBe` Nothing
      cnStatus cn `shouldBe` CNSIssued
      cnCreatedAt cn `shouldBe` day
      cnUpdatedAt cn `shouldBe` Nothing
    prop "every created note starts issued, unrelated, unmodified and dated"
         (forAll genNote $ \cn ->
            cnStatus cn == CNSIssued
              && isNothing (cnRelatedBill cn)
              && isNothing (cnUpdatedAt cn)
              && cnCreatedAt cn == cnDate cn)

  describe "Finance.CreditNote.cancelCreditNote" $ do
    it "cancels an issued note and stamps the update date" $ do
      let c = fromMaybe (mkNote 100) (cancelCreditNote (mkNote 100))
      cnStatus c `shouldBe` CNSCancelled
      isJust (cnUpdatedAt c) `shouldBe` True
    it "refuses to cancel a note that is not issued" $ do
      cancelCreditNote ((mkNote 100) { cnStatus = CNSCancelled }) `shouldBe` Nothing
      cancelCreditNote ((mkNote 100) { cnStatus = CNSApplied }) `shouldBe` Nothing
    prop "only issued notes can be cancelled"
         (forAll genNoteWithStatus $ \cn ->
            (cancelCreditNote cn /= Nothing) == (cnStatus cn == CNSIssued))
    prop "cancellation never touches the financial fields"
         (forAll genNote $ \cn ->
            let c = fromMaybe cn (cancelCreditNote cn)
            in cnAmount c == cnAmount cn
                 && cnNumber c == cnNumber cn
                 && cnCurrency c == cnCurrency cn
                 && cnReason c == cnReason cn)

  describe "Finance.CreditNote.applyCreditNote" $ do
    it "rejects a zero or negative amount" $ do
      applyCreditNote 0 (mkNote 100) `shouldBe` Nothing
      applyCreditNote (-5) (mkNote 100) `shouldBe` Nothing
    it "rejects a note that is not issued" $ do
      applyCreditNote 10 ((mkNote 100) { cnStatus = CNSCancelled }) `shouldBe` Nothing
      applyCreditNote 10 ((mkNote 100) { cnStatus = CNSApplied }) `shouldBe` Nothing
    it "applies a partial amount and keeps the note issued" $ do
      let c = fromMaybe (mkNote 100) (applyCreditNote 40 (mkNote 100))
      cnAmount c `shouldBe` 60
      cnStatus c `shouldBe` CNSIssued
    it "marks the note applied when the whole amount is consumed" $ do
      let c = fromMaybe (mkNote 100) (applyCreditNote 100 (mkNote 100))
      cnAmount c `shouldBe` 0
      cnStatus c `shouldBe` CNSApplied
    it "clamps an over-application to zero instead of going negative" $ do
      let c = fromMaybe (mkNote 100) (applyCreditNote 150 (mkNote 100))
      cnAmount c `shouldBe` 0
      cnStatus c `shouldBe` CNSApplied
    prop "a successful application never makes the remaining amount negative"
         (forAll (choose (0, 1000 :: Double)) $ \amt ->
          forAll (choose (0.01, 2000 :: Double)) $ \applied ->
            let cn = mkNote amt
            in case applyCreditNote applied cn of
                 Nothing -> applied <= 0 || cnStatus cn /= CNSIssued
                 Just c  -> cnAmount c >= 0)
    prop "partial application leaves the remainder; full/over-application zeroes it"
         (forAll (choose (0, 1000 :: Double)) $ \amt ->
          forAll (choose (0.01, 2000 :: Double)) $ \applied ->
            let cn = mkNote amt
            in case applyCreditNote applied cn of
                 Nothing -> False
                 Just c  ->
                   if applied < amt
                     then cnStatus c == CNSIssued && cnAmount c == amt - applied
                     else cnStatus c == CNSApplied && cnAmount c == 0)

  describe "Finance.CreditNote status predicates" $ do
    it "isActiveCreditNote is true exactly for CNSIssued" $
      map (\s -> isActiveCreditNote ((mkNote 1) { cnStatus = s }))
          [CNSIssued, CNSCancelled, CNSApplied]
        `shouldBe` [True, False, False]
    it "isFullyApplied is true exactly for CNSApplied" $
      map (\s -> isFullyApplied ((mkNote 1) { cnStatus = s }))
          [CNSIssued, CNSCancelled, CNSApplied]
        `shouldBe` [False, False, True]
    prop "exactly one lifecycle flag holds per note"
         (forAll genNoteWithStatus $ \cn ->
            length (filter id [ isActiveCreditNote cn
                             , isFullyApplied cn
                             , cnStatus cn == CNSCancelled ]) == 1)

  describe "Finance.CreditNote.prettyCreditNote" $ do
    it "renders the number, amount, currency and status" $
      prettyCreditNote (mkNote 99.5) { cnNumber = CreditNoteNumber "CN-42", cnCurrency = CurrencyCode "EUR" }
        `shouldBe` "CN-42 - 99.5 EUR - CNSIssued"
    prop "always contains the note number and the currency"
         (forAll genNote $ \cn ->
            T.isInfixOf (unCreditNoteNumber (cnNumber cn)) (prettyCreditNote cn)
              && T.isInfixOf (unCurrencyCode (cnCurrency cn)) (prettyCreditNote cn))
