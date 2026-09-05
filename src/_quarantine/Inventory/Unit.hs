-- | Unit module - Measurement units
module Inventory.Unit where

import Data.Int (Int64)
import Data.Text (Text)

-- | Unit - Measurement unit
data Unit = Unit
  { uId :: Int64,
    uCode :: Text, -- ISO code (m, kg, pcs)
    uName :: Text,
    uType :: UnitType,
    uRatio :: Double, -- Ratio to base unit
    uBaseId :: Maybe Int64,
    uFlags :: Int
  }
  deriving (Show, Eq)

data UnitType = UTLength | UTWeight | UTVolume | UTArea | UTCount | UTTime
  deriving (Show, Eq)

-- | Currency - Currency
data Currency = Currency
  { curId :: Int64,
    curCode :: Text, -- ISO 4217 (RUB, USD, EUR)
    curName :: Text,
    curSymbol :: Text,
    curRate :: Double, -- Exchange rate to base
    curFlags :: Int
  }
  deriving (Show, Eq)

-- | Convert quantity between units
convertUnit :: Double -> Unit -> Unit -> Maybe Double
convertUnit qty from to
  | uBaseId from == Just (uId to) = Just (qty * uRatio from)
  | uBaseId to == Just (uId from) = Just (qty / uRatio from)
  | otherwise = Nothing
