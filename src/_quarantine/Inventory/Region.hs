-- | Region module - Regions
module Inventory.Region where

import Data.Int (Int64)

-- | Region - Region
data Region = Region
  { rId :: Int64,
    rCountryId :: Int64,
    rCode :: String,
    rName :: String
  }
  deriving (Show, Eq)

-- | Get name
getRegionName :: Region -> String
getRegionName = rName
