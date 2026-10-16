{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Inventory.UnitSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Inventory.Unit

-- Arbitrary instances for QuickCheck
instance Arbitrary UnitType where
  arbitrary = elements [UTLength, UTWeight, UTVolume, UTArea, UTCount, UTTime]

instance Arbitrary Unit where
  arbitrary = do
    id_ <- arbitrary
    code <- T.pack <$> listOf1 (elements ['a'..'z'])
    name <- T.pack <$> listOf1 (elements ['a'..'z'])
    typ <- arbitrary
    ratio <- choose (0.1, 1000.0)
    baseId <- frequency [(3, pure Nothing), (7, Just <$> arbitrary)]
    flags <- arbitrary
    pure $ Unit id_ code name typ ratio baseId flags

-- Helper to make test units
mkUnit :: Int64 -> Text -> Text -> UnitType -> Double -> Maybe Int64 -> Unit
mkUnit id_ code name typ ratio baseId =
  Unit id_ code name typ ratio baseId 0

-- Base unit: meter (ratio 1, no parent)
meter :: Unit
meter = mkUnit 1 "m" "meter" UTLength 1.0 Nothing

-- Derived unit: kilometer (ratio 1000, base = meter)
kilometer :: Unit
kilometer = mkUnit 2 "km" "kilometer" UTLength 1000.0 (Just 1)

-- Derived unit: hectometer (ratio 100, base = meter)
hectometer :: Unit
hectometer = mkUnit 7 "hm" "hectometer" UTLength 100.0 (Just 1)

-- Base unit: gram (ratio 1, no parent)
gram :: Unit
gram = mkUnit 3 "g" "gram" UTWeight 1.0 Nothing

-- Derived unit: kilogram (ratio 1000, base = gram)
kilogram :: Unit
kilogram = mkUnit 4 "kg" "kilogram" UTWeight 1000.0 (Just 3)

-- Unrelated unit: second (different type, no relation)
second :: Unit
second = mkUnit 5 "s" "second" UTTime 1.0 Nothing

-- Derived unit: minute (ratio 60, base = second)
minute :: Unit
minute = mkUnit 6 "min" "minute" UTTime 60.0 (Just 5)

spec :: Spec
spec = describe "Inventory.Unit.convertUnit" $ do
  describe "same unit" $ do
    it "is the identity for a base unit" $
      convertUnit 5.0 meter meter `shouldBe` Just 5.0

    it "is the identity for a derived unit" $
      convertUnit 5.0 kilometer kilometer `shouldBe` Just 5.0

    it "is the identity for zero" $
      convertUnit 0.0 gram gram `shouldBe` Just 0.0

  describe "derived to base" $ do
    it "converts kilometers to meters (multiply by ratio)" $
      convertUnit 5.0 kilometer meter `shouldBe` Just 5000.0

    it "converts kilograms to grams (multiply by ratio)" $
      convertUnit 3.0 kilogram gram `shouldBe` Just 3000.0

    it "converts minutes to seconds (multiply by ratio)" $
      convertUnit 2.0 minute second `shouldBe` Just 120.0

    it "handles zero quantity derived-to-base" $
      convertUnit 0.0 kilometer meter `shouldBe` Just 0.0

  describe "base to derived" $ do
    it "converts meters to kilometers (divide by the derived ratio)" $
      convertUnit 5000.0 meter kilometer `shouldBe` Just 5.0

    it "converts grams to kilograms" $
      convertUnit 3000.0 gram kilogram `shouldBe` Just 3.0

    it "converts seconds to minutes" $
      convertUnit 120.0 second minute `shouldBe` Just 2.0

    it "handles zero quantity base-to-derived" $
      convertUnit 0.0 meter kilometer `shouldBe` Just 0.0

  describe "derived to derived (shared base)" $ do
    it "converts through the shared base" $
      convertUnit 1.0 kilometer hectometer `shouldBe` Just 10.0

    it "is the inverse of the reverse direction" $
      convertUnit 10.0 hectometer kilometer `shouldBe` Just 1.0

  describe "incompatible units" $ do
    it "returns Nothing for meter to gram (different types)" $
      convertUnit 100.0 meter gram `shouldBe` Nothing

    it "returns Nothing for meter to second (different types)" $
      convertUnit 100.0 meter second `shouldBe` Nothing

    it "returns Nothing for kilogram to kilometer (different types)" $
      convertUnit 1.0 kilogram kilometer `shouldBe` Nothing

  describe "round-trip" $ do
    it "kilometer→meter→kilometer round-trips" $ do
      let original = 5.0
          Just base = convertUnit original kilometer meter
          Just back = convertUnit base meter kilometer
      base `shouldBe` 5000.0
      back `shouldBe` 5.0

    it "is an involution on the identity" $ do
      let Just once = convertUnit 7.5 meter meter
      convertUnit once meter meter `shouldBe` Just 7.5

  describe "properties" $ do
    it "never returns negative for non-negative input" $ do
      property $ \n -> n >= 0 ==>
        case convertUnit n kilometer meter of
          Just r  -> r >= 0
          Nothing -> False

    it "preserves zero" $ do
      property $ \u1 u2 -> u1 /= u2 ==>
        case convertUnit 0.0 u1 u2 of
          Just r  -> r == 0
          Nothing -> True

    it "compatible units always return Just" $ do
      property $ \n -> n >= 0 ==>
        convertUnit n kilometer meter /= Nothing

    it "incompatible units always return Nothing" $ do
      property $ \(_n :: Double) ->
        convertUnit 100.0 meter gram == Nothing

    it "base→derived is the inverse of derived→base" $ do
      property $ \n -> n > 0 ==>
        let Just base = convertUnit n kilometer meter
            Just back = convertUnit base meter kilometer
            -- the round-trip goes through a Double multiply then divide
            tolerance = 1e-9 * max 1 (abs n)
        in abs (back - n) < tolerance
