-- | Scale module - Electronic scales
module Retail.Device.Scale where

import Data.Int (Int64)
import Data.Text (Text)

-- | Scale - Electronic scale
data Scale = Scale
  { scId :: Int64,
    scCode :: Text,
    scName :: Text,
    scIpAddress :: Text,
    scPort :: Int,
    scLocationId :: Int64,
    scStatus :: ScaleStatus
  }
  deriving (Show, Eq)

data ScaleStatus = SSOnline | SSOffline | SSError
  deriving (Show, Eq)

-- | ScalePLU - Price lookup
data ScalePLU = ScalePLU
  { spluId :: Int64,
    spluScaleId :: Int64,
    spluCode :: Int,
    spluGoodsId :: Int64,
    spluPrice :: Double,
    spluTare :: Double
  }
  deriving (Show, Eq)
