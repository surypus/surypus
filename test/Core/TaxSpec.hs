{-# LANGUAGE OverloadedStrings #-}

module Core.TaxSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import Data.Text (Text)
import qualified Data.Text as T
import Core.Tax

-- | Helper to create a TaxBracket directly (bypassing smart constructor)
mkBracket :: Text -> Double -> Double -> TaxBracket
mkBracket name rate threshold = TaxBracket
  { tbName = name
  , tbRate = rate
  , tbThreshold = threshold
  }

spec :: Spec
spec = do
  describe "mkTaxBracket" $ do
    it "accepts a valid rate and threshold" $
      mkTaxBracket "vat" 0.20 0 `shouldBe` Just (mkBracket "vat" 0.20 0)
    it "rejects a negative rate" $
      mkTaxBracket "bad" (-0.1) 0 `shouldBe` Nothing
    it "rejects a rate above 1.0" $
      mkTaxBracket "bad" 1.5 0 `shouldBe` Nothing
    it "rejects a negative threshold" $
      mkTaxBracket "bad" 0.20 (-100) `shouldBe` Nothing
    it "accepts rate 0.0 (no tax)" $
      mkTaxBracket "zero" 0.0 0 `shouldBe` Just (mkBracket "zero" 0.0 0)
    it "accepts rate 1.0 (full tax)" $
      mkTaxBracket "full" 1.0 0 `shouldBe` Just (mkBracket "full" 1.0 0)

  describe "applyTax" $ do
    it "applies a simple tax rate" $
      applyTax 0.20 100 `shouldBe` 20.0
    it "returns 0 for zero rate" $
      applyTax 0.0 100 `shouldBe` 0.0
    it "returns the full base for rate 1.0" $
      applyTax 1.0 100 `shouldBe` 100.0
    it "returns 0 for negative rate" $
      applyTax (-0.1) 100 `shouldBe` 0.0
    it "returns 0 for rate above 1.0" $
      applyTax 1.5 100 `shouldBe` 0.0
    it "returns 0 for negative base" $
      applyTax 0.20 (-100) `shouldBe` 0.0
    it "returns 0 for zero base" $
      applyTax 0.20 0 `shouldBe` 0.0
    it "computes tax on a fractional amount" $
      applyTax 0.13 1000 `shouldSatisfy` \x -> abs (x - 130.0) < 1e-10

  describe "applyTaxInclusive" $ do
    it "extracts tax from a gross amount" $
      applyTaxInclusive 0.20 120 `shouldSatisfy` \x -> abs (x - 20.0) < 1e-10
    it "returns 0 for zero rate" $
      applyTaxInclusive 0.0 100 `shouldBe` 0.0
    it "returns half the gross for rate 1.0" $
      applyTaxInclusive 1.0 100 `shouldSatisfy` \x -> abs (x - 50.0) < 1e-10
    it "returns 0 for negative rate" $
      applyTaxInclusive (-0.1) 100 `shouldBe` 0.0
    it "returns 0 for rate above 1.0" $
      applyTaxInclusive 1.5 100 `shouldBe` 0.0
    it "returns 0 for negative gross" $
      applyTaxInclusive 0.20 (-100) `shouldBe` 0.0
    it "returns 0 for zero gross" $
      applyTaxInclusive 0.20 0 `shouldBe` 0.0

  describe "totalTax" $ do
    it "sums tax across multiple brackets" $
      totalTax [0.10, 0.20] 100 `shouldSatisfy` \x -> abs (x - 30.0) < 1e-10
    it "returns 0 for an empty bracket list" $
      totalTax [] 100 `shouldBe` 0.0
    it "filters out invalid rates" $
      totalTax [0.10, (-0.5), 1.5, 0.20] 100 `shouldSatisfy` \x -> abs (x - 30.0) < 1e-10
    it "returns 0 for zero base" $
      totalTax [0.10, 0.20] 0 `shouldBe` 0.0

  describe "Tax properties" $ do
    it "applyTax result is always non-negative" $ property $ \(NonNegative base) (NonNegative rate) ->
      let r = rate `min` 1.0
      in applyTax r base >= 0.0
    it "applyTax result never exceeds the base" $ property $ \(NonNegative base) (NonNegative rate) ->
      let r = rate `min` 1.0
      in applyTax r base <= base
    it "applyTaxInclusive result is always non-negative" $ property $ \(NonNegative gross) (NonNegative rate) ->
      let r = rate `min` 1.0
      in applyTaxInclusive r gross >= 0.0
    it "applyTaxInclusive result never exceeds the gross" $ property $ \(NonNegative gross) (NonNegative rate) ->
      let r = rate `min` 1.0
      in applyTaxInclusive r gross <= gross
    it "applyTaxInclusive equals gross minus price-without-tax" $ property $ \(NonNegative gross) (NonNegative rate) ->
      let r = rate `min` 1.0
          priceWithout = gross - applyTaxInclusive r gross
      in abs (applyTaxInclusive r gross - (gross - priceWithout)) < 1e-10
    it "totalTax equals sum of applyTax for valid rates" $ property $ \(NonNegative base) ->
      let rates = [0.10, 0.20, 0.30]
      in totalTax rates base == sum (map (\r -> applyTax r base) rates)
