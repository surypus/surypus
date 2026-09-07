-- | Brand module - Brands
module Inventory.Brand where

import Data.Int (Int64)

-- | Brand - Brand
data Brand = Brand
  { brId :: Int64,
    brCode :: String,
    brName :: String,
    brLogo :: String
  }
  deriving (Show, Eq)

-- | Get brand name
getBrandName :: Brand -> String
getBrandName = brName
