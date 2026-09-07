-- | UnitEx module - Extended units
module Inventory.UnitEx where

import Data.Int (Int64)
import Data.Text (Text)

-- | UnitEx - Extended unit
data UnitEx = UnitEx
  { ueId :: Int64,
    ueCode :: Text,
    ueName :: Text,
    ueSymb :: Text
  }
  deriving (Show, Eq)

-- | Get unit symbol
getUnitSymbol :: UnitEx -> Text
getUnitSymbol = ueSymb
