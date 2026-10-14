-- ============================================================================
-- ADDITIONAL UNIT TESTS
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}

module AdditionalTests where

import Test.Hspec
import Data.Text (Text)
import Data.Time.Calendar (Day)
import qualified Data.Text as T
import Surypus.Foreign.QML
import Surypus.Reports.Templates
import Surypus.Reports.Conversion.CrystalTypes
import Surypus.Reports.Conversion.CrystalToPdfSlave
import Core.Payroll.Calculation

-- ============================================================================
-- MAIN
-- ============================================================================

main :: IO ()
main = hspec $ do

    describe "Text Processing" $ do
        it "concatenate texts" $ do
            let result = T.concat ["Hello", " ", "World"]
            result `shouldBe` "Hello World"

        it "check empty text" $ do
            T.null "" `shouldBe` True
            T.null "test" `shouldBe` False

        it "text length" $ do
            T.length "hello" `shouldBe` 5
