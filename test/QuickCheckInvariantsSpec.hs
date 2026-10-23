-- | QuickCheck property tests for all domain invariants
-- Patch G: Comprehensive property coverage — accounting, tax, payroll, stock
{-# LANGUAGE OverloadedStrings #-}
module QuickCheckInvariantsSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Arbitrary, Gen, Property, forAll, choose, listOf, oneof, suchThat, (.&&.), property, (===))
import Data.Int (Int64)
import Data.Text (Text, pack)
import Data.Time (Day, fromGregorian)
import Data.Decimal (Decimal)
import Data.Maybe (isJust)
import Core.Payroll.Calculation
import Inventory.Stock (Stock (..), StockFlags (..), mkStock, validateStock)

-- ============================================================================
-- Decimal generators
-- ============================================================================

genDecimal :: (Integer, Integer) -> Gen Decimal
genDecimal (lo, hi) = fromIntegral <$> choose (lo, hi)

genDecimalNonNeg :: Gen Decimal
genDecimalNonNeg = genDecimal (0, 10000000)

genDecimalSalary :: Gen Decimal
genDecimalSalary = genDecimal (0, 10000000)

genDecimalSalaryMid :: Gen Decimal
genDecimalSalaryMid = genDecimal (500000, 3500000)

genDecimalSalaryHigh :: Gen Decimal
genDecimalSalaryHigh = genDecimal (3500000, 5000000)

genDecimalSalarySocialCap :: Gen Decimal
genDecimalSalarySocialCap = genDecimal (876000, 10000000)

genDecimalSalaryLow :: Gen Decimal
genDecimalSalaryLow = genDecimal (0, 876000)

genDecimalSalaryLowBracket :: Gen Decimal
genDecimalSalaryLowBracket = genDecimal (0, 500000)

genDecimalPct :: Gen Decimal
genDecimalPct = genDecimal (0, 100)

genDecimalBonus :: Gen Decimal
genDecimalBonus = genDecimal (0, 1000000)

genDecimalAdditions :: Gen Decimal
genDecimalAdditions = genDecimal (0, 500000)

-- ============================================================================
-- Shared generators (reused by the new invariant groups)
-- ============================================================================

genInt64 :: Gen Int64
genInt64 = fromIntegral <$> (choose (0, 1000000) :: Gen Integer) :: Gen Int64

genDay :: Gen Day
genDay = fromGregorian <$> choose (2020, 2030) <*> choose (1, 12) <*> choose (1, 28)

genText :: Gen Text
genText = pack <$> listOf (choose ('a', 'z'))

arbitraryInt64 :: Gen Int64
arbitraryInt64 = genInt64

arbitraryMaybeInt64 :: Gen (Maybe Int64)
arbitraryMaybeInt64 = oneof [pure Nothing, Just <$> genInt64]

arbitraryMaybeText :: Gen (Maybe Text)
arbitraryMaybeText = oneof [pure Nothing, Just <$> genText]

arbitraryMaybeDay :: Gen (Maybe Day)
arbitraryMaybeDay = oneof [pure Nothing, Just <$> genDay]

-- ============================================================================
-- PAYROLL INVARIANTS
-- ============================================================================

-- | Net salary must never be negative
prop_calcNetSalaryNonNeg :: Property
prop_calcNetSalaryNonNeg =
  forAll genDecimalSalary $ \salary ->
    calcNetSalaryFromGross salary >= 0

-- | Income tax must never be negative
prop_calcIncomeTaxNonNeg :: Property
prop_calcIncomeTaxNonNeg =
  forAll genDecimalSalary $ \salary ->
    calcIncomeTax salary >= 0

-- | Social tax must never be negative
prop_calcSocialTaxNonNeg :: Property
prop_calcSocialTaxNonNeg =
  forAll genDecimalSalary $ \salary ->
    calcSocialTax salary >= 0

-- | Net salary must not exceed gross salary (taxes are positive)
prop_calcNetSalaryLEGross :: Property
prop_calcNetSalaryLEGross =
  forAll genDecimalSalary $ \salary ->
    calcNetSalaryFromGross salary <= salary

-- | For salary ≤ 500000, NDFL = exactly 13%
prop_ndfl_low_bracket :: Property
prop_ndfl_low_bracket =
  forAll genDecimalSalaryLowBracket $ \salary ->
    calcIncomeTax salary == salary * 0.13

-- | Annual bonus less than 3 months → zero
prop_year_end_bonus_minimum :: Property
prop_year_end_bonus_minimum =
  forAll (choose (0, 2) :: Gen Int) $ \months ->
    forAll genDecimalBonus $ \bonus ->
      calcYearEndBonus months bonus == 0

-- | Annual bonus at 12 months → full amount
prop_year_end_bonus_full :: Property
prop_year_end_bonus_full =
  forAll genDecimalBonus $ \bonus ->
    calcYearEndBonus 12 bonus == bonus

-- | Advance amount = base * pct / 100
prop_advance_amount_correct :: Property
prop_advance_amount_correct =
  forAll genDecimalBonus $ \base ->
    forAll genDecimalPct $ \pct ->
      calcAdvanceAmount base pct == base * pct / 100.0

-- | Total compensation = base + additions
prop_total_compensation :: Property
prop_total_compensation =
  forAll genDecimalBonus $ \base ->
    forAll genDecimalAdditions $ \additions ->
      calcTotalCompensation base additions == base + additions

-- | Vacation days between same date = 0
prop_vacation_zero_days :: Property
prop_vacation_zero_days =
  forAll (choose (2020, 2030) :: Gen Integer) $ \year ->
    forAll (choose (1, 12) :: Gen Int) $ \month ->
      forAll (choose (1, 28) :: Gen Int) $ \day ->
        let d = fromGregorian year month day
        in calcVacationDays d d == 0

-- ============================================================================
-- SOCIAL TAX INVARIANTS
-- ============================================================================

-- | Social tax for low salary = salary * 30%
prop_social_tax_low :: Property
prop_social_tax_low =
  forAll genDecimalSalaryLow $ \salary ->
    calcSocialTax salary == salary * 0.30

-- | Social tax for high salary = capped at 876000 * 30%
prop_social_tax_cap :: Property
prop_social_tax_cap =
  forAll genDecimalSalarySocialCap $ \salary ->
    calcSocialTax salary == 262800.0

-- ============================================================================
-- INCOME TAX PROGRESSIVE BRACKETS
-- ============================================================================

-- | Income tax for medium salary (500k-3.5M)
prop_income_tax_medium :: Property
prop_income_tax_medium =
  forAll genDecimalSalaryMid $ \salary ->
    let expected = 65000 + (salary - 500000) * 0.15
    in calcIncomeTax salary == expected

-- | Income tax for high salary (3.5M-5M)
prop_income_tax_high :: Property
prop_income_tax_high =
  forAll genDecimalSalaryHigh $ \salary ->
    let expected = 65000 + 450000 + (salary - 3500000) * 0.18
    in calcIncomeTax salary == expected

-- ============================================================================
-- STOCK INVARIANTS (TASK-030: stock invariants)
-- ============================================================================

-- | mkStock succeeds whenever every quantity is non-negative.
prop_mkStock_nonNeg :: Property
prop_mkStock_nonNeg =
  forAll (choose (0, 1000)) $ \q ->
    forAll (choose (0, 1000)) $ \r ->
      forAll (choose (0, 1000)) $ \o ->
        forAll (choose (0, 1000)) $ \c ->
          forAll (choose (0, 1000)) $ \p ->
            case mkStock 1 1 q r o c p (StockFlags False False) of
              Nothing -> property False
              Just _  -> property True

-- | validateStock returns True for any Stock created via mkStock.
prop_validateStock_mkStock :: Property
prop_validateStock_mkStock =
  forAll (choose (0, 1000)) $ \q ->
    forAll (choose (0, 1000)) $ \r ->
      forAll (choose (0, 1000)) $ \o ->
        forAll (choose (0, 1000)) $ \c ->
          forAll (choose (0, 1000)) $ \p ->
            case mkStock 1 1 q r o c p (StockFlags False False) of
              Nothing -> property False
              Just s  -> validateStock s (StockFlags False False) === True

-- | mkStock rejects a negative quantity when negativeAllowed is off.
prop_mkStock_rejectsNegativeQuantity :: Property
prop_mkStock_rejectsNegativeQuantity =
  forAll (choose (0, 1000)) $ \r ->
    forAll (choose (0, 1000)) $ \o ->
      forAll (choose (0, 1000)) $ \c ->
        forAll (choose (0, 1000)) $ \p ->
          mkStock 1 1 (-1) r o c p (StockFlags False False) === Nothing

-- | mkStock accepts a negative quantity when negativeAllowed is on.
prop_mkStock_acceptsNegativeQuantity :: Property
prop_mkStock_acceptsNegativeQuantity =
  forAll (choose (0, 1000)) $ \r ->
    forAll (choose (0, 1000)) $ \o ->
      forAll (choose (0, 1000)) $ \c ->
        forAll (choose (0, 1000)) $ \p ->
          isJust (mkStock 1 1 (-1) r o c p (StockFlags True False))

-- | Every stored field is non-negative after a successful mkStock.
prop_mkStock_fieldsNonNeg :: Property
prop_mkStock_fieldsNonNeg =
  forAll (choose (0, 1000)) $ \q ->
    forAll (choose (0, 1000)) $ \r ->
      forAll (choose (0, 1000)) $ \o ->
        forAll (choose (0, 1000)) $ \c ->
          forAll (choose (0, 1000)) $ \p ->
            case mkStock 1 1 q r o c p (StockFlags False False) of
              Nothing -> property False
              Just s  -> property $
                sQtty s >= 0 && sResrvQtty s >= 0 && sOrderedQtty s >= 0
                && sCost s >= 0 && sPrice s >= 0

-- | validateStock is True for a manually-built Stock with non-negative fields.
prop_validateStock_manual :: Property
prop_validateStock_manual =
  forAll (choose (0, 1000)) $ \q ->
    forAll (choose (0, 1000)) $ \r ->
      forAll (choose (0, 1000)) $ \o ->
        forAll (choose (0, 1000)) $ \c ->
          forAll (choose (0, 1000)) $ \p ->
            validateStock (Stock 1 1 q r o c p) (StockFlags False False) === True

-- ============================================================================
-- MAIN TEST
-- ============================================================================

spec :: Spec
spec = do
  describe "Payroll invariants" $ do
    prop "net salary ≥ 0" prop_calcNetSalaryNonNeg
    prop "income tax ≥ 0" prop_calcIncomeTaxNonNeg
    prop "social tax ≥ 0" prop_calcSocialTaxNonNeg
    prop "net salary ≤ gross" prop_calcNetSalaryLEGross
    prop "NDFL = 13% up to 500k" prop_ndfl_low_bracket
    prop "advance amount formula" prop_advance_amount_correct
    prop "total compensation = base + additions" prop_total_compensation
    prop "vacation days = 0 for same date" prop_vacation_zero_days

  describe "Payroll year-end bonus" $ do
    prop "zero for <3 months" prop_year_end_bonus_minimum
    prop "full at 12 months" prop_year_end_bonus_full

  describe "Social tax" $ do
    prop "30% for salary ≤ cap" prop_social_tax_low
    prop "capped at 262800 for high salary" prop_social_tax_cap

  describe "Income tax brackets" $ do
    prop "500k-3.5M: 15% marginal" prop_income_tax_medium
    prop "3.5M-5M: 18% marginal" prop_income_tax_high

  describe "Stock invariants" $ do
    prop "mkStock succeeds for non-negative quantities" prop_mkStock_nonNeg
    prop "validateStock True for mkStock results" prop_validateStock_mkStock
    prop "mkStock rejects negative quantity when negativeAllowed off" prop_mkStock_rejectsNegativeQuantity
    prop "mkStock accepts negative quantity when negativeAllowed on" prop_mkStock_acceptsNegativeQuantity
    prop "all fields non-negative after mkStock" prop_mkStock_fieldsNonNeg
    prop "validateStock True for manually-built Stock" prop_validateStock_manual
