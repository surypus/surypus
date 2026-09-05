-- | Manufacturer module - Manufacturers
module Inventory.Manufacturer where

import Data.Int (Int64)

-- | Manufacturer - Manufacturer
data Manufacturer = Manufacturer
  { mfrId :: Int64,
    mfrCode :: String,
    mfrName :: String,
    mfrCountry :: String
  }
  deriving (Show, Eq)

-- | Get name
getMfrName :: Manufacturer -> String
getMfrName = mfrName
