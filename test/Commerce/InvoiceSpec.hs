{-# LANGUAGE OverloadedStrings #-}

-- | First coverage for 'Commerce.Invoice' — the invoice balance layer (pure,
-- exposed, zero importers in src/+test/ before this run).
--
-- Pins the documented invariant of 'calcInvoiceBalance':
--   * the balance is always >= 0 — overpayment is never receivable, so a bill
--     paid more than its total does not produce a negative balance;
--   * a partial payment leaves the remainder owed;
--   * a payment exactly equal to the total leaves a zero balance.
module Commerce.InvoiceSpec (spec) where

import Test.Hspec
import Test.QuickCheck

import Data.Int (Int64)
import Data.Time (Day, fromGregorian)

import Commerce.Invoice

spec :: Spec
spec = do
  describe "Commerce.Invoice.calcInvoiceBalance" $ do
    it "returns the remainder owed for a partial payment" $ do
      let i = Invoice 1 "ABC-001" d0 d0 1 1000 400
      calcInvoiceBalance i `shouldBe` 600

    it "returns zero when the payment equals the total" $ do
      let i = Invoice 1 "ABC-001" d0 d0 1 1000 1000
      calcInvoiceBalance i `shouldBe` 0

    it "clamps an overpayment to zero (the NonNeg invariant)" $ do
      let i = Invoice 1 "ABC-001" d0 d0 1 1000 1250
      calcInvoiceBalance i `shouldBe` 0

    it "returns zero for a zero total" $ do
      let i = Invoice 1 "ABC-001" d0 d0 1 0 0
      calcInvoiceBalance i `shouldBe` 0

    it "never yields a negative balance" $ do
      -- Overpayment / over-measured totals must be clamped, never negative.
      forAll (choose (0, 1e6)) $ \total ->
        forAll (choose (0, 1e6)) $ \paid ->
          property (calcInvoiceBalance (Invoice 1 "X" (fromGregorian 2026 1 1) (fromGregorian 2026 1 1) 1 total paid) >= 0)

  where
    d0 = fromGregorian 2026 1 1
