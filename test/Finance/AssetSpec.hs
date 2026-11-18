{-# LANGUAGE OverloadedStrings #-}

-- | QuickCheck + unit property coverage for `Finance.Asset`
--
-- `Finance.Asset` implements the fixed-asset depreciation model:
--   * book value never falls below salvage value
--   * book value is non-increasing over time
--   * book value reaches the salvage floor exactly at end of useful life
--   * annual depreciation equals (initialCost - salvageValue) / usefulLife
--   * isFullyDepreciated is true exactly when book value is at/below salvage
--   * needsRepair is true exactly when age > 80% of useful life
--
-- Pure logic module (no DB/IO); behaviour-only spec, no production change.
module Finance.AssetSpec (spec) where

import Data.Time.Calendar (Day, addDays, diffDays, fromGregorian)
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, choose, forAll, elements)
import Test.QuickCheck.Property (Property, (===))

import Finance.Asset

-- | Generator for assets with sane depreciation parameters:
--   cost >= 1,  0 <= salvage <= cost,  1 <= life <= 50,  purchase in 2000-2010.
genAsset :: Gen Asset
genAsset = do
  cost <- choose (100, 1000000)
  salvage <- choose (0, cost)
  life <- choose (1, 50)
  purchase <- do
    y <- choose (2000, 2010)
    m <- choose (1, 12)
    d <- choose (1, 28)
    pure $ fromGregorian y m d
  method <- elements [StraightLine, DecliningBalance, UnitsOfProduction]
  pure $ createAsset (AssetId 1) (AssetCode "A0001") (AssetName "Test") BuildingAsset purchase cost salvage life method

-- | Deterministic day generator (bounds keep everything terminating).
genDay :: Gen Day
genDay = do
  y <- choose (2000, 2030)
  m <- choose (1, 12)
  d <- choose (1, 28)
  pure $ fromGregorian y m d

-- | 'true' day offset from purchase, used to pin the salvage floor exactly.
-- ageInYears = truncate(days / 365.25), days = life*1461/4 (ceil(life*365.25))
-- gives ageInYears = life, so the floor branch fires.
floorDays :: Int -> Int
floorDays life = (life * 1461 + 3) `div` 4

spec :: Spec
spec = do
  describe "Finance.Asset.createAsset / field storage" $ do
    it "stores cost, salvage and life verbatim" $ do
      let a = createAsset (AssetId 1) (AssetCode "X") (AssetName "Y") BuildingAsset (fromGregorian 2020 1 1) 100000 10000 10 StraightLine
      initialCost a `shouldBe` 100000
      salvageValue a `shouldBe` 10000
      usefulLife a `shouldBe` 10
    it "starts as AssetActive" $ do
      let a = createAsset (AssetId 1) (AssetCode "X") (AssetName "Y") BuildingAsset (fromGregorian 2020 1 1) 100000 10000 10 StraightLine
      assetStatus a `shouldBe` AssetActive

  describe "Finance.Asset.protected by invariants" $ do
    it "book value equals cost on the purchase day" $ do
      let a = createAsset (AssetId 1) (AssetCode "X") (AssetName "Y") BuildingAsset (fromGregorian 2020 1 1) 100000 10000 10 StraightLine
      currentBookValue a (fromGregorian 2020 1 1) `shouldBe` 100000
    prop "book value is never negative"
         (forAll genAsset $ \a ->
            forAll genDay $ \today ->
              currentBookValue a today >= 0)
    prop "book value never below salvage"
         (forAll genAsset $ \a ->
            forAll genDay $ \today ->
              currentBookValue a today >= salvageValue a)
    prop "annualDepreciation == (cost - salvage) / life"
         (forAll genAsset $ \a ->
            annualDepreciation a === (initialCost a - salvageValue a) / fromIntegral (usefulLife a :: Int))
    prop "isFullyDepreciated iff book value <= salvage"
         (forAll genAsset $ \a ->
            forAll genDay $ \today ->
              isFullyDepreciated a today === (currentBookValue a today <= salvageValue a))
    prop "needsRepair iff age > 80% of life"
         (forAll genAsset $ \a ->
            forAll genDay $ \today ->
              let ageYears = truncate (realToFrac (diffDays today (purchaseDate a)) / 365.25)
              in needsRepair a today === (ageYears > (usefulLife a * 80) `div` 100))
    prop "book value non-increasing over time"
         (forAll genAsset $ \a ->
            forAll genDay $ \d1 ->
              forAll (choose (0 :: Int, 3650)) $ \days ->
                let d2 = addDays (fromIntegral days) d1
                in currentBookValue a d2 <= currentBookValue a d1)
    prop "book value reaches salvage exactly at end of useful life"
         (forAll genAsset $ \a ->
            let days = floorDays (usefulLife a)
                today = addDays (fromIntegral days) (purchaseDate a)
            in currentBookValue a today === salvageValue a)

  describe "Finance.Asset.floor boundary pinning" $ do
    it "book value stops depreciating exactly at the end of useful life" $ do
      let a = createAsset (AssetId 1) (AssetCode "X") (AssetName "Y") BuildingAsset
            (fromGregorian 2020 1 1) 100000 10000 10 StraightLine
          before = addDays (fromIntegral (floorDays 10) - 1) (purchaseDate a)
          atFloor = addDays (fromIntegral (floorDays 10)) (purchaseDate a)
      currentBookValue a before `shouldBe` 100000 - annualDepreciation a * 9
      currentBookValue a atFloor `shouldBe` 10000
    it "isFullyDepreciated flips from False to True exactly at the floor" $ do
      let a = createAsset (AssetId 1) (AssetCode "X") (AssetName "Y") BuildingAsset
            (fromGregorian 2020 1 1) 100000 10000 10 StraightLine
          before = addDays (fromIntegral (floorDays 10) - 1) (purchaseDate a)
          atFloor = addDays (fromIntegral (floorDays 10)) (purchaseDate a)
      isFullyDepreciated a before `shouldBe` False
      isFullyDepreciated a atFloor `shouldBe` True
    it "needsRepair is False at age 8 and True at age 9 (threshold 80% of 10-year life)" $ do
      let a = createAsset (AssetId 1) (AssetCode "X") (AssetName "Y") BuildingAsset
            (fromGregorian 2020 1 1) 100000 10000 10 StraightLine
          age8 = addDays 2922 (purchaseDate a)   -- truncate(2922/365.25) = 8
          age9 = addDays 3288 (purchaseDate a)   -- truncate(3288/365.25) = 9
      needsRepair a age8 `shouldBe` False
      needsRepair a age9 `shouldBe` True

  describe "Finance.Asset.formula contract" $ do
    prop "currentBookValue matches the documented piecewise formula"
         (forAll genAsset $ \a ->
            forAll genDay $ \today ->
              let ageYears = truncate (realToFrac (diffDays today (purchaseDate a)) / 365.25)
                  life = usefulLife a
                  cost = initialCost a
                  salvage = salvageValue a
                  annualDep = annualDepreciation a
                  expected
                    | ageYears >= life = salvage
                    | otherwise = cost - annualDep * fromIntegral ageYears
              in currentBookValue a today === expected)
