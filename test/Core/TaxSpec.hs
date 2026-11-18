{-# LANGUAGE OverloadedStrings #-}

module Core.TaxSpec (spec) where

import Test.Hspec

import Core.Tax (calcTaxInclusive, calcTaxExclusive)
import Finance.Types (Money (..), RatePercent (..), calcVAT)
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, Property, forAll, choose, (===), (==>))
import Data.Decimal (Decimal)

-- | Convert a Double to a Money value (round to 2 decimal places)
toMoney :: Double -> Money
toMoney = Money . realToFrac

-- | Convert a Double to a RatePercent value
toRate :: Double -> RatePercent
toRate d = RatePercent $ realToFrac d

-- | Round a Double to 2 decimal places
to2 :: Double -> Double
to2 x = fromIntegral (round (x * 100)) / 100

-- ---------------------------------------------------------------------------
-- QuickCheck generators
-- ---------------------------------------------------------------------------

-- | Generate a non-negative Decimal (bounded to keep the property run fast)
genDecimalNonNeg :: Gen Decimal
genDecimalNonNeg = genDecimal (0, 10000000)

-- | Generate a Decimal in the closed interval [lo, hi]
genDecimal :: (Integer, Integer) -> Gen Decimal
genDecimal (lo, hi) = fromIntegral <$> choose (lo, hi)

-- | Generate a Money value with a non-negative amount
genMoney :: Gen Money
genMoney = Money <$> genDecimalNonNeg

-- | Generate a RatePercent in [0, 100] (two decimal places)
genRatePercent :: Gen RatePercent
genRatePercent = do
  r <- choose (0, 10000) :: Gen Integer
  pure (RatePercent ((fromIntegral r :: Decimal) / 100))

-- ---------------------------------------------------------------------------
-- | Inclusive price is never below the pre-tax price
prop_calcTaxInclusive_gePrice :: Property
prop_calcTaxInclusive_gePrice =
  forAll genRatePercent $ \rate ->
  forAll genMoney $ \amount ->
    not (unMoney amount < 0 || unRatePercent rate < 0) ==>
      unMoney amount <= unMoney (calcTaxInclusive rate amount)

-- | Inclusive price is exactly pre-tax price plus VAT
prop_calcTaxInclusive_addsVat :: Property
prop_calcTaxInclusive_addsVat =
  forAll genRatePercent $ \rate ->
  forAll genMoney $ \amount ->
    calcTaxInclusive rate amount ===
      Money (unMoney amount + unMoney (calcVAT amount rate))

-- | Inclusive price equals price * (100 + rate) / 100 (exact decimal identity)
prop_calcTaxInclusive_algebraic :: Property
prop_calcTaxInclusive_algebraic =
  forAll genRatePercent $ \rate ->
  forAll genMoney $ \amount ->
    unMoney (calcTaxInclusive rate amount) ===
      unMoney amount * (100 + unRatePercent rate) / 100

-- | Exclusive price is never less than half of the pre-tax price
prop_calcTaxExclusive_geHalf :: Property
prop_calcTaxExclusive_geHalf =
  forAll genRatePercent $ \rate ->
  forAll genMoney $ \amount ->
    not (unMoney amount < 0 || unRatePercent rate > 100) ==>
      unMoney amount / 2 <= unMoney (calcTaxExclusive rate amount)

-- | Exclusive price is never above the pre-tax price
prop_calcTaxExclusive_lePrice :: Property
prop_calcTaxExclusive_lePrice =
  forAll genRatePercent $ \rate ->
  forAll genMoney $ \amount ->
    not (unMoney amount < 0 || unRatePercent rate < 0) ==>
      unMoney (calcTaxExclusive rate amount) <= unMoney amount

-- | Exclusive price is never above the inclusive price
prop_calcTaxExclusive_leInclusive :: Property
prop_calcTaxExclusive_leInclusive =
  forAll genRatePercent $ \rate ->
  forAll genMoney $ \amount ->
    not (unMoney amount < 0 || unRatePercent rate < 0) ==>
      unMoney (calcTaxExclusive rate amount) <=
        unMoney (calcTaxInclusive rate amount)

spec :: Spec
spec = do
  describe "calcVAT" $ do
    it "computes 20% VAT on 100 = 20" $
      unMoney (calcVAT (toMoney 100.0) (toRate 20.0)) `shouldBe` 20.0
    it "computes 0% VAT on any amount = 0" $
      unMoney (calcVAT (toMoney 100.0) (toRate 0.0)) `shouldBe` 0.0
    it "calculates 100% VAT = full amount" $
      unMoney (calcVAT (toMoney 100.0) (toRate 100.0)) `shouldBe` 100.0

  describe "calcTaxInclusive" $ do
    it "computes 20% VAT on 100 = 120" $
      calcTaxInclusive (toRate 20.0) (toMoney 100.0) `shouldBe` toMoney 120.0
    it "computes 0% VAT on any amount = 0" $
      calcTaxInclusive (toRate 0.0) (toMoney 100.0) `shouldBe` toMoney 100.0
    it "calculates 100% VAT on 100 = 200" $
      calcTaxInclusive (toRate 100.0) (toMoney 100.0) `shouldBe` toMoney 200.0
    it "calculates inclusive tax for 10% rate" $
      calcTaxInclusive (toRate 10.0) (toMoney 100.0) `shouldBe` toMoney 110.0

  describe "calcTaxExclusive" $ do
    it "calculates exclusive tax correctly" $
      calcTaxExclusive (toRate 20.0) (toMoney 120.0) `shouldBe` toMoney 100.0
    it "calculates exclusive tax for 0% rate" $
      calcTaxExclusive (toRate 0.0) (toMoney 100.0) `shouldBe` toMoney 100.0
    it "calculates exclusive tax for 0 amount" $
      calcTaxExclusive (toRate 20.0) (toMoney 0.0) `shouldBe` toMoney 0.0
    it "calculates exclusive tax for 10% rate" $
      calcTaxExclusive (toRate 10.0) (toMoney 110.0) `shouldBe` toMoney 100.0

  describe "QuickCheck properties" $ do
    prop "inclusive price >= pre-tax price"
         prop_calcTaxInclusive_gePrice
    prop "inclusive price == pre-tax price + VAT"
         prop_calcTaxInclusive_addsVat
    prop "inclusive price == price * (100 + rate) / 100"
         prop_calcTaxInclusive_algebraic
    prop "exclusive price >= half of pre-tax price"
         prop_calcTaxExclusive_geHalf
    prop "exclusive price <= pre-tax price"
         prop_calcTaxExclusive_lePrice
    prop "exclusive price <= inclusive price"
         prop_calcTaxExclusive_leInclusive
