{-# LANGUAGE OverloadedStrings #-}

module EventProcessorSpec (spec) where

import qualified Data.Text as T
import Data.List (nub)
import Integration.API.EventProcessor (generateEventId)
import Test.Hspec

spec :: Spec
spec = describe "generateEventId" $ do
  it "produces a non-empty identifier" $ do
    ident <- generateEventId
    ident `shouldSatisfy` (not . T.null)

  it "does not repeat" $ do
    ids <- sequence (replicate 64 generateEventId)
    length (nub ids) `shouldBe` 64
