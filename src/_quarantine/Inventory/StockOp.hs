-- | StockOp module - Stock operations
module Inventory.StockOp where

import Data.Int (Int64)
import Data.Time (Day)

-- | StockOp - Stock operation
data StockOp = StockOp
  { soId :: Int64,
    soType :: StockOpType,
    soGoodsId :: Int64,
    soLocationId :: Int64,
    soQtty :: Double,
    soDate :: Day,
    soBillId :: Maybe Int64
  }
  deriving (Show, Eq)

data StockOpType = SOReceipt | SOIssue | SOTransfer | SOAdjustment | SOInventory
  deriving (Show, Eq)

-- | StockOpHistory - Stock operation history
data StockOpHistory = StockOpHistory
  { sohId :: Int64,
    sohGoodsId :: Int64,
    sohLocationId :: Int64,
    sohQtty :: Double,
    sohBalance :: Double,
    sohDate :: Day
  }
  deriving (Show, Eq)
