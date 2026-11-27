{-# LANGUAGE OverloadedStrings #-}
module Finance.CanonSpec (spec) where

import Test.Hspec
import Finance.Canon

spec :: Spec
spec = describe "Finance.Canon" $ do
  describe "weightedAverageCost" $ do
    it "weights by quantity" $
      weightedAverageCost [(10, 100), (30, 200)] `shouldBe` Right 175

    it "rejects zero total quantity" $
      weightedAverageCost [] `shouldBe` Left "total quantity must be positive"

  describe "cogs" $ do
    it "multiplies shipped quantity by average cost" $
      cogs 4 175 `shouldBe` 700

  describe "trialBalance" $ do
    it "accepts balanced kopeck-exact totals" $
      trialBalance [("10", 100.01, 0), ("60", 0, 100.01)] `shouldBe` Right (10001, 10001)

    it "rejects unbalanced totals" $
      trialBalance [("10", 100.01, 0), ("60", 0, 100.00)] `shouldBe` Left "trial balance is not balanced"
