{-# LANGUAGE OverloadedStrings #-}
module ConfigSpec (spec) where

import Test.Hspec
import qualified Data.Text as T
import qualified Surypus.Domain.Config.Config as CFG

spec :: Spec
spec = do
  describe "Config" $ do
    it "has default values" $ do
      let cfg = CFG.defaultConfig
      CFG.rcLogLevel cfg `shouldBe` T.pack "INFO"
      CFG.rcMaxWorkers cfg `shouldBe` 4
