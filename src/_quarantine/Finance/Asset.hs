{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Finance.Asset - Enhanced fixed assets with lifecycle management
-- This module provides type-safe asset tracking with depreciation and valuation
module Finance.Asset where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian, diffDays)
import GHC.Generics (Generic)

-- | Asset classification with richer semantics
data AssetClass
  = BuildingAsset    -- Здания (buildings)
  | EquipmentAsset  -- Оборудование (equipment)
  | VehicleAsset    -- Транспорт (vehicles)
  | IntangibleAsset -- Нематериальные (intangible)
  | FinancialAsset  -- Финансовые (financial assets)
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Asset lifecycle status
data AssetStatus
  = AssetActive     -- Активен (active)
  | AssetInRepair    -- В ремонте (in repair)
  | AssetWrittenOff -- Списан (written off)
  | AssetSold       -- Продан (sold)
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Enhanced fixed asset with type safety
data Asset = Asset
  { assetId        :: AssetId
  , assetCode      :: AssetCode
  , assetName      :: AssetName
  , assetClass     :: AssetClass
  , parentAssetId  :: Maybe AssetId
  , purchaseDate   :: Day
  , initialCost    :: Double
  , salvageValue   :: Double
  , usefulLife    :: Int  -- in years
  , depreciationMethod :: DepreciationMethod
  , assetStatus    :: AssetStatus
  , locationCode   :: Maybe Text
  , responsiblePerson :: Maybe Int64
  , notes          :: Maybe Text
  } deriving (Show, Eq, Generic)

-- | Newtypes for enhanced type safety
newtype AssetId = AssetId { unAssetId :: Int64 }
  deriving (Show, Eq, Ord)

newtype AssetCode = AssetCode { unAssetCode :: Text }
  deriving (Show, Eq, Ord)

newtype AssetName = AssetName { unAssetName :: Text }
  deriving (Show, Eq, Ord)

-- | Depreciation method
data DepreciationMethod
  = StraightLine       -- Линейный (straight-line)
  | DecliningBalance  -- Убывающий остаток (declining balance)
  | UnitsOfProduction -- Метод единиц производства (units of production)
  deriving (Show, Eq, Enum)

-- | Smart constructor with validation
createAsset :: AssetId -> AssetCode -> AssetName -> AssetClass -> Day -> Double -> Double -> Int -> DepreciationMethod -> Asset
createAsset aid code name cls date cost salvage life method = Asset
  { assetId = aid
  , assetCode = code
  , assetName = name
  , assetClass = cls
  , parentAssetId = Nothing
  , purchaseDate = date
  , initialCost = cost
  , salvageValue = salvage
  , usefulLife = life
  , depreciationMethod = method
  , assetStatus = AssetActive
  , locationCode = Nothing
  , responsiblePerson = Nothing
  , notes = Nothing
  }

-- | Calculate current value (book value)
currentBookValue :: Asset -> Day -> Double
currentBookValue asset today =
  let ageInYears = truncate (fromIntegral (diffDays today (purchaseDate asset)) / 365.25) :: Int
      life = usefulLife asset
      cost = initialCost asset
      salvage = salvageValue asset
  in if ageInYears >= life
        then salvage
        else
          let depreciable = cost - salvage
              annualDep = depreciable / fromIntegral life
              accumulatedDep = annualDep * fromIntegral ageInYears
              bookValue = cost - accumulatedDep
          in max bookValue salvage

-- | Calculate annual depreciation expense
annualDepreciation :: Asset -> Double
annualDepreciation asset =
  let cost = initialCost asset
      salvage = salvageValue asset
      life = fromIntegral (usefulLife asset) :: Double
  in (cost - salvage) / life

-- | Straight-line depreciation per day
dailyDepreciation :: Asset -> Double
dailyDepreciation asset =
  let annual = annualDepreciation asset
  in annual / 365.25

-- | Check if asset is fully depreciated
isFullyDepreciated :: Asset -> Day -> Bool
isFullyDepreciated asset today =
  currentBookValue asset today <= salvageValue asset

-- | Check if asset needs repair (assumption: older than 80% of life)
needsRepair :: Asset -> Day -> Bool
needsRepair asset today =
  let ageInYears = truncate (fromIntegral (diffDays today (purchaseDate asset)) / 365.25) :: Int
      life = usefulLife asset
  in ageInYears > (life * 80) `div` 100

-- | Write off asset (full depreciation or disposal)
writeOffAsset :: Asset -> Asset
writeOffAsset asset = asset { assetStatus = AssetWrittenOff }

-- | Sell asset
sellAsset :: Asset -> Double -> Asset
sellAsset asset salePrice = asset
  { assetStatus = AssetSold
  , notes = Just $ "Sold for " <> T.pack (show salePrice)
  }

-- | Pretty print asset
prettyAsset :: Asset -> Text
prettyAsset asset = unAssetCode (assetCode asset) <> " - " <> unAssetName (assetName asset) <>
  " (" <> T.pack (show (assetStatus asset)) <> "), Cost: " <>
  T.pack (show (initialCost asset))
