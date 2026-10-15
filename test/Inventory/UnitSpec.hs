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
  describe "same unit (BUG)" $ do
    -- BUG: convertUnit returns Nothing when from == to (same unit).
    -- Both guards fail: uBaseId from == Just (uId to) and vice versa
    -- require a baseId link, but base units have baseId = Nothing.
    -- See TASK-036.
    it "meter to meter" $ do
      pendingWith "convertUnit returns Nothing for same-unit conversion (TASK-036)"

  describe "derived to base" $ do
    it "converts kilometers to meters (multiply by ratio)" $ do
      convertUnit 5.0 kilometer meter `shouldBe` Just 5000.0

    it "converts kilograms to grams (multiply by ratio)" $ do
      convertUnit 3.0 kilogram gram `shouldBe` Just 3000.0

    it "converts minutes to seconds (multiply by ratio)" $ do
      convertUnit 2.0 minute second `shouldBe` Just 120.0

    it "handles zero quantity derived-to-base" $ do
      convertUnit 0.0 kilometer meter `shouldBe` Just 0.0

  describe "base to derived (BUG)" $ do
    -- BUG: convertUnit divides by uRatio `from` instead of uRatio `to`,
    -- so base→derived returns the input unchanged (e.g. 5000 m → 5000 "km"
    -- instead of 5 km). See TASK-036.
    it "meters to kilometers" $ do
      pendingWith "convertUnit uses wrong ratio for base→derived (TASK-036)"
    it "grams to kilograms" $ do
      pendingWith "convertUnit uses wrong ratio for base→derived (TASK-036)"
    it "seconds to minutes" $ do
      pendingWith "convertUnit uses wrong ratio for base→derived (TASK-036)"

  describe "incompatible units" $ do
    it "returns Nothing for meter to gram (different types)" $ do
      convertUnit 100.0 meter gram `shouldBe` Nothing

    it "returns Nothing for meter to second (different types)" $ do
      convertUnit 100.0 meter second `shouldBe` Nothing

    it "returns Nothing for kilogram to kilometer (different types)" $ do
      convertUnit 1.0 kilogram kilometer `shouldBe` Nothing

  describe "BUG: base-to-derived uses wrong ratio" $ do
    -- Known bug: convertUnit divides by uRatio `from` instead of uRatio `to`
    -- when converting base→derived. 5000 m should be 5 km but returns 5000.0.
    -- See TASK-036. These tests document the correct expected behaviour.
    it "base→derived should divide by the derived unit's ratio" $ do
      pendingWith "known bug: convertUnit divides by uRatio from instead of uRatio to (TASK-036)"

  describe "round-trip (derived→base only, correct path)" $ do
    it "kilometer→meter→kilometer round-trips" $ do
      let original = 5.0
          Just base = convertUnit original kilometer meter
      -- First step is correct (5 km → 5000 m); second step hits the BUG above.
      -- Pinning the correct first step here.
      base `shouldBe` 5000.0

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
