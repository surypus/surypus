-- | GoodsReceipt module - Goods receipt
module Inventory.GoodsReceipt where

import Data.Int (Int64)
import Data.Time (Day)

-- | GoodsReceipt - Goods receipt
data GoodsReceipt = GoodsReceipt
  { grId :: Int64,
    grNumber :: String,
    grDate :: Day,
    grSupplierId :: Int64,
    grWarehouseId :: Int64,
    grStatus :: ReceiptStatus
  }
  deriving (Show, Eq)

data ReceiptStatus = RSPending | RSReceived | RSChecked | RSVerified
  deriving (Show, Eq)

-- | Is received
isReceived :: GoodsReceipt -> Bool
isReceived gr = grStatus gr == RSReceived || grStatus gr == RSChecked
