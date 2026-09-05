-- | Address module - Addresses
module HR.Address where

import Data.Int (Int64)

-- | Address - Address
data Address = Address
  { adrId :: Int64,
    adrPersonId :: Int64,
    adrCityId :: Int64,
    adrStreet :: String,
    adrBuilding :: String,
    adrOffice :: String
  }
  deriving (Show, Eq)

-- | Get full address
getFullAddress :: Address -> String
getFullAddress a = adrStreet a <> " " <> adrBuilding a <> ", " <> adrOffice a
