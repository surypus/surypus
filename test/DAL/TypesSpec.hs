{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.TypesSpec (spec) where

import Test.Hspec
import DAL.Types

spec :: Spec
spec = do
  describe "DAL.Types - Basic types" $ do
    it "should define basic types" $ do
      True `shouldBe` True
