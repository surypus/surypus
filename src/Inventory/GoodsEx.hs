-- | GoodsEx module - Extended goods
module Inventory.GoodsEx where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T

-- | GoodsEx - Extended goods
data GoodsEx = GoodsEx
  { geId :: Int64,
    geCode :: Text,
    geName :: Text,
    geBarcode :: Text,
    geUnitId :: Int64
  }
  deriving (Show, Eq)

-- | Get goods display name
getGoodsDisplayName :: GoodsEx -> Text
getGoodsDisplayName g = geCode g `T.append` T.pack " - " `T.append` geName g
