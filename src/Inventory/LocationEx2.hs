-- | LocationEx2 module - Extended location
module Inventory.LocationEx2 where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T

-- | LocationEx2 - Extended location
data LocationEx2 = LocationEx2
  { le2Id :: Int64,
    le2Code :: Text,
    le2Name :: Text,
    le2Address :: Text,
    le2Type :: LocType2
  }
  deriving (Show, Eq)

data LocType2 = LT2_Warehouse | LT2_Store | LT2_Office | LT2_Transit
  deriving (Show, Eq)

-- | Get location description
getLocationDesc :: LocationEx2 -> Text
getLocationDesc l = le2Name l `T.append` T.pack " - " `T.append` le2Address l
