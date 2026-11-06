{-# LANGUAGE OverloadedStrings #-}

-- | QuickCheck property tests for 'Commerce.Discount' — the discount-rule
-- layer (pure, no DB; zero importers in src/+test/ before this run).
--
-- Pins the documented invariants of 'calcDiscount':
--   * the result is never negative;
--   * a discount never applies below its minimum-amount threshold;
--   * for a fixed discount ('DTFixed') the returned amount equals the fixed
--     value as soon as the threshold is met;
--   * for a percentage discount ('DTPercent') the result is linear in the
--     amount, i.e. additive across two independent amounts.
module Commerce.DiscountSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck

import Commerce.Discount

-- | Generator for 'Discount' values (deterministic codes).
instance Arbitrary Discount where
  arbitrary = do
    dscId <- arbitrary
    dscCode <- pure "DISC-001"
    dscName <- pure "Discount"
    dscType <- elements [DTPercent, DTFixed, DTConditional]
    dscValue <- choose (0, 100)
    dscMinAmount <- choose (0, 1000)
    pure $ Discount dscId dscCode dscName dscType dscValue dscMinAmount

spec :: Spec
spec = do
  describe "Commerce.Discount.calcDiscount" $ do
    prop "never returns a negative amount" prop_calcDiscount_nonNeg
    prop "returns zero below the minimum-amount threshold"
      prop_calcDiscount_belowMin
    prop "returns the fixed value once the threshold is met (DTFixed)"
      prop_calcDiscount_fixedValue
    prop "percentage discount is linear in the amount (DTPercent)"
      prop_calcDiscount_percentLinear

-- | 'calcDiscount' is always non-negative for a non-negative input amount.
prop_calcDiscount_nonNeg :: Discount -> Double -> Property
prop_calcDiscount_nonNeg d amount =
  amount >= 0 ==> calcDiscount d amount >= 0

-- | A discount never activates below its minimum-amount threshold.
prop_calcDiscount_belowMin ::
     Discount -> Double -> Property
prop_calcDiscount_belowMin d amount =
  amount >= 0 ==>
    amount < dscMinAmount d ==>
      calcDiscount d amount == 0

-- | A fixed discount ('DTFixed') pays out exactly the fixed value once the
-- threshold is met (no scaling beyond it).
prop_calcDiscount_fixedValue :: Discount -> Property
prop_calcDiscount_fixedValue d =
  dscType d == DTFixed ==>
    forAll (choose (dscMinAmount d, 10000)) $ \amount ->
      calcDiscount d amount == dscValue d

-- | A percentage discount ('DTPercent') is linear in the amount up to the
-- floating-point rounding that 'Double' arithmetic introduces, i.e. two
-- independent amounts above the threshold discount exactly as one amount
-- equal to their sum (within 1 cent of rounding).
prop_calcDiscount_percentLinear :: Discount -> Property
prop_calcDiscount_percentLinear d =
  dscType d == DTPercent ==>
    forAll (choose (dscMinAmount d, 10000)) $ \amount1 ->
      forAll (choose (dscMinAmount d, 10000)) $ \amount2 ->
        abs (calcDiscount d (amount1 + amount2) -
               (calcDiscount d amount1 + calcDiscount d amount2)) < 0.01
