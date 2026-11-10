{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.RefinedSpec
  ( spec,
  )
where

import Test.Hspec
import Test.QuickCheck (forAll, choose, Gen, Property, (==>), property)

import Surypus.Refined

spec :: Spec
spec = describe "Surypus.Refined" $ do
  describe "clampNonNeg" $ do
    it "is the identity on non-negative input" $ property $
      forAll (choose (0.0, 1000.0) :: Gen Double) $ \x -> clampNonNeg x == x
    it "maps negative input to zero" $ property $
      forAll (choose (-1000.0, -1.0) :: Gen Double) $ \x -> clampNonNeg x == 0
    it "never returns a negative result" $ property $
      \x -> clampNonNeg x >= 0
    it "is idempotent" $ property $
      \x -> clampNonNeg (clampNonNeg x) == clampNonNeg x
  describe "clampPercentage" $ do
    it "always returns a value within [0,100]" $ property $
      \x -> let r = clampPercentage x in r >= 0 && r <= 100
    it "is the identity on the [0,100] range" $ property $
      forAll (choose (0.0, 100.0) :: Gen Double) $ \x -> clampPercentage x == x
    it "clamps below zero to zero" $ property $
      forAll (choose (-1000.0, -1.0) :: Gen Double) $ \x -> clampPercentage x == 0
    it "clamps above 100 to 100" $ property $
      forAll (choose (101.0, 1000.0) :: Gen Double) $ \x -> clampPercentage x == 100
    it "is idempotent" $ property $
      \x -> clampPercentage (clampPercentage x) == clampPercentage x
  describe "isNonNeg" $ do
    it "is equivalent to >= 0" $ property $
      \x -> isNonNeg x == (x >= 0)
  describe "combineNonNeg" $ do
    it "is always non-negative" $ property $
      \a b -> combineNonNeg a b >= 0
    it "is commutative" $ property $
      \a b -> combineNonNeg a b == combineNonNeg b a
    it "adds non-negative inputs" $ property $
      \(a :: Double) -> \(b :: Double) -> a >= 0 ==> b >= 0 ==> combineNonNeg a b == a + b
    it "absorbs a zero argument" $ property $
      \a -> combineNonNeg a 0 == clampNonNeg a
