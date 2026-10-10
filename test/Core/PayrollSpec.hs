{-# LANGUAGE OverloadedStrings #-}

module Core.PayrollSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import Data.Decimal (Decimal, roundTo)
import Data.Time (Day, fromGregorian)
import Core.Payroll.Calculation

spec :: Spec
spec = do
  describe "calcIncomeTax" $ do
    it "returns 0 for zero salary" $
      calcIncomeTax 0 `shouldBe` 0

    it "returns 0 for negative salary" $
      calcIncomeTax (-1000) `shouldBe` 0

    it "applies 13% rate for salary ≤ 500k" $
      calcIncomeTax 100000 `shouldBe` 13000

    it "applies 13% rate at exactly 500k" $
      calcIncomeTax 500000 `shouldBe` 65000

    it "applies 15% marginal rate for salary ≤ 3.5M" $
      calcIncomeTax 1000000 `shouldBe` (65000 + 500000 * 0.15)

    it "applies 15% marginal rate at exactly 3.5M" $
      calcIncomeTax 3500000 `shouldBe` (65000 + 3000000 * 0.15)

    it "applies 18% marginal rate for salary ≤ 5M" $
      calcIncomeTax 4000000 `shouldBe` (65000 + 450000 + 500000 * 0.18)

    it "applies 18% marginal rate at exactly 5M" $
      calcIncomeTax 5000000 `shouldBe` (65000 + 450000 + 1500000 * 0.18)

    it "applies 20% marginal rate for salary > 5M" $
      calcIncomeTax 6000000 `shouldBe` (65000 + 450000 + 270000 + 1000000 * 0.20)

    it "is monotonically non-decreasing" $
      property prop_incomeTax_monotonic

  describe "calcSocialTax" $ do
    it "returns 0 for zero salary" $
      calcSocialTax 0 `shouldBe` 0

    it "returns 0 for negative salary" $
      calcSocialTax (-5000) `shouldBe` 0

    it "applies 30% rate for salary ≤ 876k" $
      calcSocialTax 100000 `shouldBe` 30000

    it "applies 30% rate at exactly 876k" $
      calcSocialTax 876000 `shouldBe` 262800

    it "caps at 876k for salary above cap" $
      calcSocialTax 1000000 `shouldBe` 262800

    it "is monotonically non-decreasing" $
      property prop_socialTax_monotonic

  describe "calcNetSalaryFromGross" $ do
    it "returns 0 for zero gross" $
      calcNetSalaryFromGross 0 `shouldBe` 0

    it "returns 0 for negative gross" $
      calcNetSalaryFromGross (-1000) `shouldBe` 0

    it "net salary is always ≤ gross" $
      property prop_netSalary_leq_gross

    it "net salary equals gross minus income tax" $
      property prop_netSalary_formula

  describe "calcVacationDays" $ do
    it "returns 0 for same start and end date" $
      calcVacationDays (fromGregorian 2024 6 1) (fromGregorian 2024 6 1) `shouldBe` 0

    it "returns positive days for valid range" $
      calcVacationDays (fromGregorian 2024 6 1) (fromGregorian 2024 6 14) `shouldBe` 13

    it "returns negative days for reversed range" $
      calcVacationDays (fromGregorian 2024 6 14) (fromGregorian 2024 6 1) `shouldBe` (-13)

  describe "calcSickLeavePay" $ do
    it "employer pays 60% for first 3 days" $
      calcSickLeavePay 1000 3 True `shouldBe` 1800

    it "employer pays 60% capped at 3 days" $
      calcSickLeavePay 1000 10 True `shouldBe` 1800

    it "social insurance pays 80% for remaining days" $
      calcSickLeavePay 1000 10 False `shouldBe` 5600

    it "social insurance pays 0 for ≤ 3 days" $
      calcSickLeavePay 1000 3 False `shouldBe` 0

    it "returns 0 for zero days" $
      calcSickLeavePay 1000 0 True `shouldBe` 0

  describe "calcYearEndBonus" $ do
    it "returns 0 for less than 3 months" $
      calcYearEndBonus 2 12000 `shouldBe` 0

    it "returns 0 for zero months" $
      calcYearEndBonus 0 12000 `shouldBe` 0

    it "prorates bonus for 6 months" $
      calcYearEndBonus 6 12000 `shouldBe` 6000

    it "returns full bonus for 12 months" $
      calcYearEndBonus 12 12000 `shouldBe` 12000

    it "prorates bonus for 3 months" $
      calcYearEndBonus 3 12000 `shouldBe` 3000

  describe "calcAdvanceAmount" $ do
    it "calculates 50% advance" $
      calcAdvanceAmount 100000 50 `shouldBe` 50000

    it "calculates 100% advance" $
      calcAdvanceAmount 100000 100 `shouldBe` 100000

    it "returns 0 for 0% advance" $
      calcAdvanceAmount 100000 0 `shouldBe` 0

  describe "calcMonthlyAdvance" $ do
    it "calculates 40% of base" $
      calcMonthlyAdvance 100000 `shouldBe` 40000

    it "returns 0 for zero base" $
      calcMonthlyAdvance 0 `shouldBe` 0

  describe "calcTotalCompensation" $ do
    it "sums base and additions" $
      calcTotalCompensation 100000 20000 `shouldBe` 120000

    it "returns base when additions are zero" $
      calcTotalCompensation 100000 0 `shouldBe` 100000

-- | Generate non-negative Decimal
genNonNegDecimal :: Gen Decimal
genNonNegDecimal = fromIntegral <$> choose (0, 10000000 :: Integer)

-- | Properties

prop_incomeTax_monotonic :: Property
prop_incomeTax_monotonic = forAll genNonNegDecimal $ \s1 ->
  forAll genNonNegDecimal $ \s2 ->
    s1 <= s2 ==> calcIncomeTax s1 <= calcIncomeTax s2

prop_socialTax_monotonic :: Property
prop_socialTax_monotonic = forAll genNonNegDecimal $ \s1 ->
  forAll genNonNegDecimal $ \s2 ->
    s1 <= s2 ==> calcSocialTax s1 <= calcSocialTax s2

prop_netSalary_leq_gross :: Property
prop_netSalary_leq_gross = forAll genNonNegDecimal $ \gross ->
  calcNetSalaryFromGross gross <= gross

prop_netSalary_formula :: Property
prop_netSalary_formula = forAll genNonNegDecimal $ \gross ->
  calcNetSalaryFromGross gross == gross - calcIncomeTax gross
