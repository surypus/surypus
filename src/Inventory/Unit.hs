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

-- | Convert a quantity between two units.
--
-- A unit's @uRatio@ is the number of base units contained in one of that unit,
-- so a derived unit carries its own ratio and points at its base via @uBaseId@,
-- while a base unit has ratio 1 and no parent.
--
--   * the same unit is the identity
--   * derived -> base multiplies by the derived unit's ratio
--   * base -> derived divides by the derived unit's ratio
--   * two derived units sharing a base are converted through that base
--   * anything else (different types, unknown relation) is 'Nothing'
convertUnit :: Double -> Unit -> Unit -> Maybe Double
convertUnit qty from to
  | uId from == uId to = Just qty
  | uBaseId from == Just (uId to) = Just (qty * uRatio from)
  | uBaseId to == Just (uId from) = Just (qty / uRatio to)
  | Just baseFrom <- uBaseId from,
    Just baseTo <- uBaseId to,
    baseFrom == baseTo =
      Just (qty * uRatio from / uRatio to)
  | otherwise = Nothing
