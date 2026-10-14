{-# LANGUAGE OverloadedStrings #-}
-- | Main test entry point
module Test.Main where

import Test.Hspec
import Domain.TypesSpec

main :: IO ()
main = hspec $ do
  describe "Domain Types" typesSpec
