-- | Bundle module - Product bundles
module Commerce.Bundle  where

import Data.Int (Int64)

-- | Bundle - Product bundle
data Bundle = Bundle
  { bndId :: Int64,
    bndCode :: String,
    bndName :: String,
    bndPrice :: Double,
    bndGoodsIds :: String
  }
  deriving (Show, Eq)

-- | Get price
getBundlePrice :: Bundle -> Double
getBundlePrice = bndPrice
