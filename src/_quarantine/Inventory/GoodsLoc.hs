-- | GoodsLoc module - Goods at location
module Inventory.GoodsLoc where

import Data.Int (Int64)

-- | GoodsLoc - Goods at location
data GoodsLoc = GoodsLoc
  { glId :: Int64,
    glGoodsId :: Int64,
    glLocationId :: Int64,
    glQtty :: Double,
    glResrvQtty :: Double,
    glCost :: Double
  }
  deriving (Show, Eq)

-- | Reserve goods
reserveGoods :: GoodsLoc -> Double -> Maybe GoodsLoc
reserveGoods gl qty
  | glQtty gl - glResrvQtty gl >= qty = Just gl {glResrvQtty = glResrvQtty gl + qty}
  | otherwise = Nothing
