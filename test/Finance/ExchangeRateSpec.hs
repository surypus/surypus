{-# LANGUAGE OverloadedStrings #-}

module Finance.ExchangeRateSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import Data.Time (Day, fromGregorian)
import qualified Data.Text as T
import Finance.ExchangeRate

-- Helpers
mkRate :: Double -> Day -> ExchangeRate
mkRate r date = createExchangeRate (RateId 1) (CurrencyCode "USD") (CurrencyCode "EUR") r date CentralBank

mkRatePair :: Double -> Double -> Day -> (ExchangeRate, ExchangeRate)
mkRatePair r1 r2 date =
  ( createExchangeRate (RateId 1) (CurrencyCode "USD") (CurrencyCode "EUR") r1 date CentralBank,
    createExchangeRate (RateId 2) (CurrencyCode "EUR") (CurrencyCode "GBP") r2 date CentralBank
  )

prop_convertCurrency_nonPositive :: Double -> Property
prop_convertCurrency_nonPositive amount =
  amount <= 0 ==>
    case convertCurrency amount (mkRate 0.85 (fromGregorian 2026 1 1)) of
      Just _ -> property False
      Nothing -> property True

prop_convertCurrency_positive :: Double -> Property
prop_convertCurrency_positive amount =
  amount > 0 ==>
    case convertCurrency amount (mkRate 0.85 (fromGregorian 2026 1 1)) of
      Nothing -> property False
      Just v -> property (v > 0)

prop_convertCurrency_amountProportional :: Double -> Property
prop_convertCurrency_amountProportional amount =
  amount > 0 ==>
    forAll (choose (0.01, 10 :: Double)) $ \rate ->
      let r = mkRate rate (fromGregorian 2026 1 1)
          Just v = convertCurrency amount r
      in property (abs (v - amount * rate) <= 1e-9)

prop_inverseRate_composes :: Property
prop_inverseRate_composes =
  forAll (choose (0.01, 100 :: Double)) $ \rateValue ->
    let r = mkRate rateValue (fromGregorian 2026 1 1)
        inv = case inverseRate r of
          Nothing -> 0
          Just v -> v
    in property (if inv > 0 then abs (inv * rateValue - 1.0) <= 1e-9 else True)

prop_isValidOnDate_monotonic :: Property
prop_isValidOnDate_monotonic =
  forAll genDay $ \closeDate ->
    forAll genDay $ \laterDate ->
      laterDate > closeDate ==>
        let rate = closeExchangeRate closeDate (mkRate 0.85 (fromGregorian 2026 1 1))
         in property (isValidOnDate laterDate rate == False)

-- | A QuickCheck generator for 'Day' values in a fixed range (uses the 'Gen' monad).
genDay :: Gen Day
genDay = do
  y <- choose (2020, 2030)
  m <- choose (1, 12)
  d <- choose (1, 28)
  pure (fromGregorian y m d)

spec :: Spec
spec = describe "Finance.ExchangeRate" $ do
  describe "createExchangeRate" $ do
    it "creates an active rate with no end date" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      erIsActive rate `shouldBe` True
      erEffectiveTo rate `shouldBe` Nothing
      erRate rate `shouldBe` 0.85

    it "sets the source correctly" $ do
      let rate = createExchangeRate (RateId 1) (CurrencyCode "USD") (CurrencyCode "EUR") 1.0 (fromGregorian 2026 1 1) CommercialBank
      erSource rate `shouldBe` CommercialBank

  describe "isValidOnDate" $ do
    it "is valid on the effective date" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      isValidOnDate (fromGregorian 2026 1 1) rate `shouldBe` True

    it "is valid after the effective date" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      isValidOnDate (fromGregorian 2026 6 1) rate `shouldBe` True

    it "is invalid before the effective date" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      isValidOnDate (fromGregorian 2025 12 31) rate `shouldBe` False

    it "is invalid after the end date" $ do
      let rate = closeExchangeRate (fromGregorian 2026 6 30) (mkRate 0.85 (fromGregorian 2026 1 1))
      isValidOnDate (fromGregorian 2026 7 1) rate `shouldBe` False

    it "is invalid on the end date (close deactivates)" $ do
      let rate = closeExchangeRate (fromGregorian 2026 6 30) (mkRate 0.85 (fromGregorian 2026 1 1))
      isValidOnDate (fromGregorian 2026 6 30) rate `shouldBe` False

    it "is invalid when inactive even within date range" $ do
      let rate = (mkRate 0.85 (fromGregorian 2026 1 1)) { erIsActive = False }
      isValidOnDate (fromGregorian 2026 3 1) rate `shouldBe` False

  describe "closeExchangeRate" $ do
    it "sets the end date and deactivates" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
          closed = closeExchangeRate (fromGregorian 2026 6 30) rate
      erEffectiveTo closed `shouldBe` Just (fromGregorian 2026 6 30)
      erIsActive closed `shouldBe` False
      erUpdatedAt closed `shouldBe` Just (fromGregorian 2026 6 30)

    it "preserves the rate value" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
          closed = closeExchangeRate (fromGregorian 2026 6 30) rate
      erRate closed `shouldBe` 0.85

  describe "convertCurrency" $ do
    it "converts a positive amount" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      convertCurrency 100 rate `shouldBe` Just 85.0

    it "returns Nothing for zero amount" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      convertCurrency 0 rate `shouldBe` Nothing

    it "returns Nothing for negative amount" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      convertCurrency (-50) rate `shouldBe` Nothing

    it "result is positive when amount is positive" $ do
      let rate = mkRate 1.5 (fromGregorian 2026 1 1)
      convertCurrency 10 rate `shouldBe` Just 15.0

  describe "inverseRate" $ do
    it "computes the inverse" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      inverseRate rate `shouldBe` Just (1.0 / 0.85)

    it "returns Nothing for zero rate" $ do
      let rate = mkRate 0 (fromGregorian 2026 1 1)
      inverseRate rate `shouldBe` Nothing

    it "inverseRate * rate ≈ 1" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      case inverseRate rate of
        Nothing -> expectationFailure "expected Just"
        Just inv -> (inv * 0.85) `shouldBe` 1.0

  describe "prettyExchangeRate" $ do
    it "contains the currency codes" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      let s = prettyExchangeRate rate
      s `shouldSatisfy` T.isInfixOf "USD"
      s `shouldSatisfy` T.isInfixOf "EUR"

    it "contains the rate value" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      prettyExchangeRate rate `shouldSatisfy` T.isInfixOf "0.85"

    it "contains Active status" $ do
      let rate = mkRate 0.85 (fromGregorian 2026 1 1)
      prettyExchangeRate rate `shouldSatisfy` T.isInfixOf "Active"

  describe "calculateCrossRate" $ do
    it "computes cross rate for chained currencies" $ do
      let (r1, r2) = mkRatePair 0.85 0.90 (fromGregorian 2026 1 1)
      calculateCrossRate r1 r2 `shouldBe` Just (0.85 / 0.90)

    it "returns Nothing for non-chaining rates" $ do
      let r1 = createExchangeRate (RateId 1) (CurrencyCode "USD") (CurrencyCode "EUR") 0.85 (fromGregorian 2026 1 1) CentralBank
      let r2 = createExchangeRate (RateId 2) (CurrencyCode "USD") (CurrencyCode "GBP") 0.75 (fromGregorian 2026 1 1) CentralBank
      calculateCrossRate r1 r2 `shouldBe` Nothing

    it "returns Nothing when second rate is zero" $ do
      let r1 = createExchangeRate (RateId 1) (CurrencyCode "USD") (CurrencyCode "EUR") 0.85 (fromGregorian 2026 1 1) CentralBank
      let r2 = createExchangeRate (RateId 2) (CurrencyCode "EUR") (CurrencyCode "GBP") 0 (fromGregorian 2026 1 1) CentralBank
      calculateCrossRate r1 r2 `shouldBe` Nothing

  describe "QuickCheck properties" $ do
    it "convertCurrency returns Nothing for zero/negative amounts"
      (property prop_convertCurrency_nonPositive)
    it "convertCurrency returns a positive result for positive amounts"
      (property prop_convertCurrency_positive)
    it "convertCurrency scales linearly with the amount"
      (property prop_convertCurrency_amountProportional)
    it "inverseRate * rate ≈ 1" (property prop_inverseRate_composes)
    it "isValidOnDate is monotonic after closing" (property prop_isValidOnDate_monotonic)
