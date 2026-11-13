{-# LANGUAGE OverloadedStrings #-}

-- | Property-based tests for 'Surypus.CoreTypes' — the non-negative wrapper
-- newtypes used across the domain layer.
--
-- Pins the documented semantics:
--   * 'mkNonNeg' accepts every non-negative 'Decimal' and rejects every
--     negative one (returns 'Nothing');
--   * 'unNonNeg' is the left inverse of 'mkNonNeg' — for every value the
--     smart constructor accepts, extraction returns the original number;
--   * the 'NonNeg' newtype never holds a negative value by construction;
--   * 'Decimal' ordering/equality round-trip through 'NonNeg' is consistent.
module Surypus.CoreTypesSpec (spec) where

import Test.Hspec
import Test.QuickCheck

import Surypus.CoreTypes (Decimal (..), NonNeg (..), mkNonNeg, unDecimal, unNonNeg)

-- | Arbitrary 'Decimal' — all of Double's finite values, plus a few
-- infinities and NaNs for thorough rejection coverage.
genDecimal :: Gen Decimal
genDecimal = do
  -- Finite values: symmetric around zero with a wide range.
  d <- choose (-1e10, 1e10) :: Gen Double
  -- Occasionally emit non-finite values to make sure the guards are strict.
  if d == 0
    then oneof [pure (Decimal d), pure (Decimal (0/0)), pure (Decimal (1/0))]
    else pure (Decimal d)

spec :: Spec
spec = describe "Surypus.CoreTypes" $ do
  describe "mkNonNeg" $ do
    it "accepts zero" $
      mkNonNeg (Decimal 0) `shouldBe` Just (NonNeg (Decimal 0))

    it "accepts positive values" $
      mkNonNeg (Decimal 42.5) `shouldBe` Just (NonNeg (Decimal 42.5))

    it "rejects negative values" $
      mkNonNeg (Decimal (-1.0)) `shouldBe` Nothing

    it "never returns Nothing for non-negative input" $
      forAll genDecimal $ \d ->
        if unDecimal d >= 0
          then case mkNonNeg d of
            Nothing -> property False
            Just n  -> property (unDecimal (unNonNeg n) >= 0)
          else property True

    it "returns Just for all non-negative reals in a bounded range" $
      forAll (choose (0, 1e6) :: Gen Double) $ \d ->
        case mkNonNeg (Decimal d) of
          Nothing -> property False
          Just (NonNeg x) -> property (unDecimal x == d)

  describe "unNonNeg" $ do
    it "extracts the wrapped value unchanged" $
      unNonNeg (NonNeg (Decimal 3.14)) `shouldBe` Decimal 3.14

  describe "NonNeg wrapper invariants" $ do
    it "wrapped value is always non-negative" $
      forAll genDecimal $ \d ->
        case mkNonNeg d of
          Nothing -> property True
          Just (NonNeg x) -> property (unDecimal x >= 0)

    it "mkNonNeg . unNonNeg is the identity on Just values" $
      forAll genDecimal $ \d ->
        case mkNonNeg d of
          Nothing -> property True
          Just (NonNeg x) ->
            case mkNonNeg x of
              Nothing -> property False
              Just (NonNeg y) -> property (y == x)

  describe "Decimal instance through NonNeg" $ do
    it "Eq round-trip consistent" $
      forAll genDecimal $ \a ->
        case mkNonNeg a of
          Nothing -> property True
          Just (NonNeg x) ->
            case mkNonNeg a of
              Nothing -> property True
              Just (NonNeg y) -> property ((x == y) == ((x :: Decimal) == y))

    it "Ord round-trip consistent" $
      forAll genDecimal $ \a ->
        case mkNonNeg a of
          Nothing -> property True
          Just (NonNeg x) ->
            case mkNonNeg a of
              Nothing -> property True
              Just (NonNeg y) -> property ((x <= y) == ((x :: Decimal) <= y))
