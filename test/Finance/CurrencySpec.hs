{-# LANGUAGE OverloadedStrings #-}

-- | Unit and property-based tests for Finance.Currency.
-- Tests currency conversion, rounding, and formatting functions.
module Finance.CurrencySpec (spec) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Finance.Currency
import Test.Hspec
import Test.QuickCheck

-- Helpers

mkCurrency :: Int64 -> Text -> Text -> Double -> Int -> Currency
mkCurrency id code name rate precision =
  Currency
    { curId = id,
      curCode = code,
      curName = name,
      curSymbol = T.take 1 code,
      curRate = rate,
      curPrecision = precision,
      curFlags = CurrencyFlags False False False
    }

usd :: Currency
usd = mkCurrency 1 "USD" "US Dollar" 1.0 2

eur :: Currency
eur = mkCurrency 2 "EUR" "Euro" 0.85 2

jpy :: Currency
jpy = mkCurrency 3 "JPY" "Japanese Yen" 110.0 0

-- | Property: convertAmount with same currency returns the amount unchanged
prop_sameCurrency :: Double -> Property
prop_sameCurrency amount =
  forAll (elements [usd, eur, jpy]) $ \cur ->
    convertAmount cur cur amount `shouldBe` amount

-- | Property: convertAmount is multiplicative in the amount
prop_convertMultiplicative :: Property
prop_convertMultiplicative =
  forAll (choose (0, 10000)) $ \amount ->
    convertAmount usd eur amount `shouldBe` (amount * 1.0 / 0.85)

-- | Property: roundToCurrency never changes the sign
prop_roundPreservesSign :: Property
prop_roundPreservesSign =
  forAll (choose (-10000, 10000)) $ \amount ->
    forAll (elements [usd, eur, jpy]) $ \cur ->
      let rounded = roundToCurrency cur amount
       in (rounded < 0) == (amount < 0)

-- | Property: roundToCurrency result is within 0.5 * 10^(-precision) of input
prop_roundBounded :: Property
prop_roundBounded =
  forAll (choose (-10000, 10000)) $ \amount ->
    forAll (elements [usd, eur, jpy]) $ \cur ->
      let rounded = roundToCurrency cur amount
          bound = 0.5 * 10 ^^ (- curPrecision cur)
       in abs (rounded - amount) <= bound

-- | Property: formatAmount always contains the currency symbol
prop_formatContainsSymbol :: Property
prop_formatContainsSymbol =
  forAll (choose (0, 10000)) $ \amount ->
    forAll (elements [usd, eur, jpy]) $ \cur ->
      T.isInfixOf (curSymbol cur) (formatAmount cur amount)

-- | Property: formatAmount always produces non-empty text
prop_formatNonEmpty :: Property
prop_formatNonEmpty =
  forAll (choose (-10000, 10000)) $ \amount ->
    forAll (elements [usd, eur, jpy]) $ \cur ->
      not (T.null (formatAmount cur amount))

-- | Property: convertAmount result is non-negative when the input is
-- non-negative (matches the @NonNeg@ refinement on the result).
prop_convertAmountNonNeg :: Property
prop_convertAmountNonNeg =
  forAll (choose (0, 10000)) $ \amount ->
    forAll (elements [usd, eur, jpy]) $ \from ->
      forAll (elements [usd, eur, jpy]) $ \to ->
        convertAmount from to amount >= 0

-- | Property: convertAmount is additive in the amount for fixed source and
-- target currencies: convertAmount c1 c2 (a + b) == c1->c2 a + c1->c2 b.
prop_convertAmountAdditive :: Property
prop_convertAmountAdditive =
  forAll (choose (0, 10000)) $ \a ->
    forAll (choose (0, 10000)) $ \b ->
      forAll (elements [usd, eur, jpy]) $ \from ->
        forAll (elements [usd, eur, jpy]) $ \to ->
          let lhs = convertAmount from to (a + b)
              rhs = convertAmount from to a + convertAmount from to b
              scale = max 1.0 (max (abs lhs) (abs rhs))
           in abs (lhs - rhs) <= 1e-9 * scale

spec = describe "Finance.Currency" $ do
  describe "convertAmount" $ do
    it "converts USD to EUR correctly" $
      convertAmount usd eur 100 `shouldBe` (100 * 1.0 / 0.85)

    it "converts EUR to USD correctly" $
      convertAmount eur usd 85 `shouldBe` (85 * 0.85 / 1.0)

    it "returns 0 when target rate is 0" $
      convertAmount usd (eur {curRate = 0}) 100 `shouldBe` 0

    it "returns amount unchanged for same currency" $ do
      convertAmount usd usd 50 `shouldBe` 50
      convertAmount eur eur 13.0 `shouldBe` 13.0
      convertAmount jpy jpy 999.99 `shouldBe` 999.99

    it "handles zero amount" $
      convertAmount usd eur 0 `shouldBe` 0

    it "handles large amounts" $
      convertAmount usd eur 1000000 `shouldBe` (1000000 * 1.0 / 0.85)

  describe "roundToCurrency" $ do
    it "rounds to 2 decimal places for USD" $
      roundToCurrency usd 123.456 `shouldBe` 123.46

    it "rounds to 0 decimal places for JPY" $
      roundToCurrency jpy 123.7 `shouldBe` 124.0

    it "handles exact values without change" $
      roundToCurrency usd 100.00 `shouldBe` 100.0

    it "handles negative amounts" $
      roundToCurrency usd (-123.456) `shouldBe` (-123.46)

    it "handles zero" $
      roundToCurrency usd 0 `shouldBe` 0

    it "rounds half to even" $
      roundToCurrency jpy 123.5 `shouldBe` 124.0

  describe "formatAmount" $ do
    it "formats USD amount with symbol" $
      formatAmount usd 123.45 `shouldBe` "U123.45"

    it "formats EUR amount with symbol" $
      formatAmount eur 85.00 `shouldBe` "E85.0"

    it "formats JPY amount with symbol" $
      formatAmount jpy 124 `shouldBe` "J124.0"

    it "formats zero" $
      formatAmount usd 0 `shouldBe` "U0.0"

    it "formats negative amounts" $
      formatAmount usd (-50.25) `shouldBe` "U-50.25"

  describe "properties" $ do
    it "same currency returns amount unchanged" $
      property prop_sameCurrency
    it "conversion is multiplicative" $
      property prop_convertMultiplicative
    it "rounding preserves sign" $
      property prop_roundPreservesSign
    it "rounding is bounded by precision" $
      property prop_roundBounded
    it "format contains currency symbol" $
      property prop_formatContainsSymbol
    it "format produces non-empty text" $
      property prop_formatNonEmpty
    it "conversion result is non-negative" $
      property prop_convertAmountNonNeg
    it "conversion is additive" $
      property prop_convertAmountAdditive
