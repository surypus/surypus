{-# LANGUAGE OverloadedStrings #-}

module Surypus.ValidationSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import qualified Data.Text as T
import Surypus.Validation
import DAL.Types (AccTurnInput(..))

spec :: Spec
spec = do
  describe "validateAccTurnInput" $ do
    it "accepts valid input" $
      validateAccTurnInput (AccTurnInput 1 2 100.0 (Just "Test"))
        `shouldBe` Right ()

    it "rejects zero debit account" $
      validateAccTurnInput (AccTurnInput 0 2 100.0 Nothing)
        `shouldSatisfy` isLeft

    it "rejects negative debit account" $
      validateAccTurnInput (AccTurnInput (-1) 2 100.0 Nothing)
        `shouldSatisfy` isLeft

    it "rejects zero credit account" $
      validateAccTurnInput (AccTurnInput 1 0 100.0 Nothing)
        `shouldSatisfy` isLeft

    it "rejects negative credit account" $
      validateAccTurnInput (AccTurnInput 1 (-2) 100.0 Nothing)
        `shouldSatisfy` isLeft

    it "rejects zero amount" $
      validateAccTurnInput (AccTurnInput 1 2 0.0 Nothing)
        `shouldSatisfy` isLeft

    it "rejects negative amount" $
      validateAccTurnInput (AccTurnInput 1 2 (-100.0) Nothing)
        `shouldSatisfy` isLeft

    it "accepts Nothing description" $
      validateAccTurnInput (AccTurnInput 1 2 50.0 Nothing)
        `shouldBe` Right ()

    it "accepts Just description" $
      validateAccTurnInput (AccTurnInput 1 2 50.0 (Just "Description"))
        `shouldBe` Right ()

  describe "validatePersonInput" $ do
    it "accepts valid name" $
      validatePersonInput "John" Nothing Nothing
        `shouldBe` Right ()

    it "rejects empty name" $
      validatePersonInput "" Nothing Nothing
        `shouldSatisfy` isLeft

    it "rejects whitespace-only name" $
      validatePersonInput "   " Nothing Nothing
        `shouldSatisfy` isLeft

  describe "validateINN" $ do
    it "accepts 10-digit INN" $
      validateINN "1234567890"
        `shouldBe` Right "1234567890"

    it "accepts 12-digit INN" $
      validateINN "123456789012"
        `shouldBe` Right "123456789012"

    it "rejects 9-digit INN" $
      validateINN "123456789"
        `shouldSatisfy` isLeft

    it "rejects 11-digit INN" $
      validateINN "12345678901"
        `shouldSatisfy` isLeft

    it "rejects non-numeric INN" $
      validateINN "123456789a"
        `shouldSatisfy` isLeft

  describe "validateKPP" $ do
    it "accepts 9-digit KPP" $
      validateKPP "123456789"
        `shouldBe` Right "123456789"

    it "rejects 8-digit KPP" $
      validateKPP "12345678"
        `shouldSatisfy` isLeft

    it "rejects non-numeric KPP" $
      validateKPP "12345678a"
        `shouldSatisfy` isLeft

  describe "validateCurrencyInput" $ do
    it "accepts 3-char code" $
      validateCurrencyInput "USD" "US Dollar"
        `shouldBe` Right ()

    it "rejects 2-char code" $
      validateCurrencyInput "US" "US Dollar"
        `shouldSatisfy` isLeft

    it "rejects 4-char code" $
      validateCurrencyInput "USDD" "US Dollar"
        `shouldSatisfy` isLeft

  describe "validateGoodsInput" $ do
    it "accepts valid name" $
      validateGoodsInput "Product" "ART001"
        `shouldBe` Right ()

    it "rejects empty name" $
      validateGoodsInput "" "ART001"
        `shouldSatisfy` isLeft

  describe "validateLocationInput" $ do
    it "accepts valid name" $
      validateLocationInput "Warehouse A"
        `shouldBe` Right ()

    it "rejects empty name" $
      validateLocationInput ""
        `shouldSatisfy` isLeft

  describe "validatePaymentInput" $ do
    it "accepts positive amount" $
      validatePaymentInput 100.0 (read "2024-01-01")
        `shouldBe` Right ()

    it "rejects zero amount" $
      validatePaymentInput 0.0 (read "2024-01-01")
        `shouldSatisfy` isLeft

    it "rejects negative amount" $
      validatePaymentInput (-50.0) (read "2024-01-01")
        `shouldSatisfy` isLeft

  describe "validatePriceInput" $ do
    it "accepts positive price" $
      validatePriceInput 99.99
        `shouldBe` Right ()

    it "accepts zero price" $
      validatePriceInput 0.0
        `shouldBe` Right ()

    it "rejects negative price" $
      validatePriceInput (-10.0)
        `shouldSatisfy` isLeft

  describe "validateTaxInput" $ do
    it "accepts valid tax" $
      validateTaxInput "VAT" 20.0
        `shouldBe` Right ()

    it "rejects empty name" $
      validateTaxInput "" 20.0
        `shouldSatisfy` isLeft

    it "rejects negative rate" $
      validateTaxInput "VAT" (-5.0)
        `shouldSatisfy` isLeft

    it "rejects rate > 100" $
      validateTaxInput "VAT" 150.0
        `shouldSatisfy` isLeft

  describe "QuickCheck properties" $ do
    it "validateAccTurnInput accepts valid inputs" $
      property prop_valid_accturn
    it "validateINN matches isValidINN" $
      property prop_validateINN_matches
    it "validateKPP matches isValidKPP" $
      property prop_validateKPP_matches

-- | Helper functions
isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft _        = False

-- | Generate valid AccTurnInput
genValidAccTurnInput :: Gen AccTurnInput
genValidAccTurnInput = do
  dbt <- choose (1, 1000)
  crd <- choose (1, 1000)
  amt <- choose (0.01, 10000.0)
  desc <- elements [Nothing, Just "Test", Just "Description"]
  return $ AccTurnInput dbt crd amt desc

-- | Property: valid AccTurnInput passes validation
prop_valid_accturn :: Property
prop_valid_accturn = forAll genValidAccTurnInput $ \input ->
  validateAccTurnInput input == Right ()

-- | Property: validateINN matches isValidINN
prop_validateINN_matches :: Property
prop_validateINN_matches = forAll (listOf1 (elements ['0'..'9'])) $ \digits ->
  let inn = T.pack digits
  in validateINN inn == (if isValidINN inn then Right inn else Left InvalidINN)

-- | Property: validateKPP matches isValidKPP
prop_validateKPP_matches :: Property
prop_validateKPP_matches = forAll (listOf1 (elements ['0'..'9'])) $ \digits ->
  let kpp = T.pack digits
  in validateKPP kpp == (if isValidKPP kpp then Right kpp else Left InvalidKPP)
