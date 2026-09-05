-- | Location types - Warehouses and stores
module Inventory.Location where

import Data.Int (Int64)
import Data.Text (Text)

-- | Location ID must be positive

{-@ type LocationId = {v:Int64 | v > 0} @-}

-- | Location - Warehouse or store
data Location = Location
  { locId :: Int64,
    locCode :: Text,
    locName :: Text,
    locType :: LocationType,
    locParentId :: Maybe Int64,
    locAddress :: Text,
    locFlags :: Int
  }
  deriving (Show, Eq)

-- | Location type
data LocationType
  = LTWarehouse -- Склад
  | LTStore -- Магазин
  | LTOffice -- Офис
  | LTTransit -- Транзит
  deriving (Show, Eq, Enum)

-- | Location flags
data LocationFlags = LocationFlags
  { lfActive :: Bool,
    lfPrimary :: Bool,
    lfAcceptReturns :: Bool
  }
  deriving (Show, Eq)
