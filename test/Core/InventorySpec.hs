{-# LANGUAGE OverloadedStrings #-}

-- | First coverage for 'Core.Inventory' — the stock-balance invariant
-- (pure, no DB; zero importers in src/+test/ before this run).
--
-- Pins the documented invariant: Rest = Initial + Receipt - Issue.
module Core.InventorySpec (spec) where

import Test.Hspec
import Test.QuickCheck

import Core.Inventory

spec :: Spec
spec = do
  describe "Core.Inventory.stockBalance" $ do
    it "returns initial + receipt - issue" $ do
      stockBalance 10.0 5.0 2.0 `shouldBe` 13.0

    it "handles zero receipt and zero issue" $ do
      stockBalance 10.0 0.0 0.0 `shouldBe` 10.0

    it "handles zero initial" $ do
      stockBalance 0.0 5.0 2.0 `shouldBe` 3.0

    it "handles zero across the board" $ do
      stockBalance 0.0 0.0 0.0 `shouldBe` 0.0

    it "shortage yields a negative remainder (no clamping)" $ do
      stockBalance 10.0 0.0 15.0 `shouldBe` (-5.0)

  describe "Core.Inventory.stockBalance (property)" $ do
    it "satisfies the stock-balance invariant for all non-negative inputs" $ do
      property $ \a b c ->
        stockBalance a b c == a + b - c

    it "is non-negative when the issue does not exceed initial + receipt" $ do
      property $ \a b c ->
        a >= 0.0 && b >= 0.0 && c >= 0.0 && a + b >= c ==>
          stockBalance a b c >= 0.0
