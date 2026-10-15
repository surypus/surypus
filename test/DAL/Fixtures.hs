{-# LANGUAGE OverloadedStrings #-}

module DAL.Fixtures (spec) where

import Test.Hspec

spec :: Spec
spec = do
  describe "DAL Fixtures" $ do
    it "placeholder" $ do
      True `shouldBe` True
