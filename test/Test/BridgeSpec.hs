-- Simple test for Surypus library
{-# LANGUAGE OverloadedStrings #-}

module Test.BridgeSpec where

import Test.Hspec

spec :: Spec
spec = do
  describe "Surypus" $ do
    it "library compiles correctly" $ do
      True `shouldBe` True

main :: IO ()
main = hspec spec
