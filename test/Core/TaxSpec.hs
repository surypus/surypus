{-# LANGUAGE OverloadedStrings #-}

module Core.TaxSpec (spec) where

import Test.Hspec

import Core.Tax
import Finance.Types (Money (..), RatePercent (..), calcVAT)

-- | Convert a Double to a Money value (round to 2 decimal places)
toMoney :: Double -> Money
toMoney = Money . realToFrac

-- | Convert a Double to a RatePercent value
toRate :: Double -> RatePercent
toRate d = RatePercent $ realToFrac d

-- | Round a Double to 2 decimal places
to2 :: Double -> Double
to2 x = fromIntegral (round (x * 100)) / 100

spec :: Spec
spec = do
  describe "calcVAT" $ do
    it "computes 20% VAT on 100 = 20" $
      unMoney (calcVAT (toMoney 100.0) (toRate 20.0)) `shouldBe` 20.0
    it "computes 10% VAT on 50 = 5" $
      unMoney (calcVAT (toMoney 50.0) (toRate 10.0)) `shouldBe` 5.0
    it "computes 0% VAT on any amount = 0" $
      unMoney (calcVAT (toMoney 100.0) (toRate 0.0)) `shouldBe` 0.0
    it "calculates 100% VAT = full amount" $
      unMoney (calcVAT (toMoney 100.0) (toRate 100.0)) `shouldBe` 100.0

  describe "calcTaxInclusive" $ do
    it "calculates inclusive tax correctly" $
      unMoney (calcTaxInclusive (toRate 20.0) (toMoney 100.0)) `shouldBe` 120.0
    it "calculates inclusive tax for zero rate" $
      unMoney (calcTaxInclusive (toRate 0.0) (toMoney 100.0)) `shouldBe` 100.0
    it "calculates inclusive tax for zero amount" $
      unMoney (calcTaxInclusive (toRate 20.0) (toMoney 0.0)) `shouldBe` 0.0
    it "calculates inclusive tax for 10% rate" $
      unMoney (calcTaxInclusive (toRate 10.0) (toMoney 100.0)) `shouldBe` 110.0

  describe "calcTaxExclusive" $ do
    it "calculates exclusive tax correctly" $
      unMoney (calcTaxExclusive (toRate 20.0) (toMoney 120.0)) `shouldBe` 100.0
    it "calculates exclusive tax for zero rate" $
      unMoney (calcTaxExclusive (toRate 0.0) (toMoney 100.0)) `shouldBe` 100.0
    it "calculates exclusive tax for zero amount" $
      unMoney (calcTaxExclusive (toRate 20.0) (toMoney 0.0)) `shouldBe` 0.0
    it "calculates exclusive tax for 10% rate" $
      unMoney (calcTaxExclusive (toRate 10.0) (toMoney 110.0)) `shouldBe` 100.0
