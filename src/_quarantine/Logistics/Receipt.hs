-- | Receipt module - Purchase receipts
module Logistics.Receipt where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Receipt - Purchase receipt (arrival)
data Receipt = Receipt
  { rcId :: Int64,
    rcCode :: Text,
    rcDate :: Day,
    rcSupplierId :: Int64,
    rcLocationId :: Int64,
    rcStatus :: ReceiptStatus,
    rcFlags :: Int
  }
  deriving (Show, Eq)

data ReceiptStatus = RSDraft | RSReceived | RSChecked | RSAccepted | RSRejected
  deriving (Show, Eq)

-- | Receipt line
data ReceiptLine = ReceiptLine
  { rlId :: Int64,
    rlReceiptId :: Int64,
    rlGoodsId :: Int64,
    rlOrderedQtty :: Double,
    rlReceivedQtty :: Double,
    rlPrice :: Double,
    rlFlags :: Int
  }
  deriving (Show, Eq)

-- | Check if receipt matches order
checkReceiptMatch :: ReceiptLine -> Double -> Bool
checkReceiptMatch rl ordered = rlReceivedQtty rl == ordered
