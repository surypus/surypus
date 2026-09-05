-- | LocationEx module - Extended location
module Inventory.LocationEx where

import Data.Int (Int64)
import Data.Text (Text)

-- | LocationEx - Extended location with coordinates
data LocationEx = LocationEx
  { locId :: Int64,
    locAddress :: Text,
    locLat :: Double,
    locLon :: Double,
    locTimezone :: Text
  }
  deriving (Show, Eq)

-- | LocationZone - Location delivery zone
data LocationZone = LocationZone
  { lzId :: Int64,
    lzLocationId :: Int64,
    lzName :: Text,
    lzPolygon :: Text, -- JSON coordinates
    lzDeliveryCost :: Double
  }
  deriving (Show, Eq)
