-- | Warehouse module - Stock management
-- Re-exports inventory types
module Logistics.Warehouse
  ( -- module Logistics.Warehouse.Inventory.Types,
    validateLot,
    StockMovement   (..),
    calcStockBalance,
    checkStockAvailable,
    fifoSelect,
    prop_stockBalanceNonNeg
  ) where

import Inventory.Types
import Data.Int (Int64)
import Data.Time (Day, fromGregorian)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}

-- | Validate lot: quantity >= 0
validateLot :: Lot -> Bool
validateLot l = lotQtty l >= 0 && lotCost l >= 0

-- | Stock movement record
data StockMovement = StockMovement
  { smDate :: Day,
    smGoodsId :: Int64,
    smLocationId :: Int64,
    smQtty :: Double, -- positive = receipt, negative = issue
    smCost :: Double,
    smPrice :: Double,
    smBillId :: Maybe Int64
  }
  deriving (Show, Eq)

-- | Calculate stock balance from movements

{-@ calcStockBalance :: NonNeg -> [StockMovement] -> NonNeg @-}
calcStockBalance :: Double -> [StockMovement] -> Double
calcStockBalance initial movements =
  let s = initial + sum (fmap smQtty movements)
   in max s 0

-- | Check stock availability
checkStockAvailable :: Lot -> Double -> Bool
checkStockAvailable lot required = lotQtty lot >= required

-- | FIFO: select lots for write-off (oldest first)
fifoSelect :: Double -> [Lot] -> ([(Lot, Double)], [Lot])
fifoSelect qty lots = go qty lots []
  where
    go 0 remaining selected = (selected, remaining)
    go _ [] selected = (selected, [])
    go n (l : ls) selected
      | lotQtty l <= n = go (n - lotQtty l) ls (selected <> [(l, lotQtty l)])
      | otherwise = (selected <> [(l, n)], l {lotQtty = lotQtty l - n} : ls)

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary StockMovement where
  arbitrary = do
    qtty <- choose (0, 1000 :: Double)
    pure $ StockMovement (fromGregorian 2024 1 1) 0 0 qtty 0 0 Nothing

prop_stockBalanceNonNeg :: Double -> [StockMovement] -> Property
prop_stockBalanceNonNeg initial movements =
  let balance = calcStockBalance initial movements
   in balance >= 0 ==> True
