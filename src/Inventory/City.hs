-- | City module - Cities
module Inventory.City where

import Data.Int (Int64)

-- | City - City
data City = City
  { ctId :: Int64,
    ctRegionId :: Int64,
    ctCode :: String,
    ctName :: String,
    ctTimeZone :: String
  }
  deriving (Show, Eq)

-- | Get name
getCityName :: City -> String
getCityName = ctName
