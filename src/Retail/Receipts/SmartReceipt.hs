{-# LANGUAGE OverloadedStrings #-}

-- | SmartReceipt module - Electronic receipts
module Retail.Receipts.SmartReceipt
  ( SmartReceipt   (..),
    PaymentType   (..),
    ReceiptStatus   (..),
    SmartReceiptLine   (..),
    calcReceiptTotal,
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime)

{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ type Discount = {v:Double | v >= 0 && v <= 100} @-}

-- | SmartReceipt - Electronic receipt
data SmartReceipt = SmartReceipt
  { srId :: Int64,
    srCode :: Text,
    srSessionId :: Int64,
    srDate :: Day,
    srTime :: UTCTime,
    srTotal :: Double,
    srTax :: Double,
    srPaymentType :: PaymentType,
    srStatus :: ReceiptStatus
  }
  deriving (Show, Eq)

data PaymentType = PTCash | PTCard | PTOnline | PTBonus
  deriving (Show, Eq)

data ReceiptStatus = RSPrinted | RSSent | RSReturned
  deriving (Show, Eq)

-- | SmartReceiptLine - Receipt line
data SmartReceiptLine = SmartReceiptLine
  { srlId :: Int64,
    srlReceiptId :: Int64,
    srlGoodsId :: Int64,
    srlName :: Text,
    srlQtty :: Double,
    srlPrice :: Double,
    srlDiscount :: Double,
    srlTax :: Double
  }
  deriving (Show, Eq)

-- | Calculate receipt total

{-@ calcReceiptTotal :: [SmartReceiptLine] -> NonNeg @-}
calcReceiptTotal :: [SmartReceiptLine] -> Double
calcReceiptTotal receiptLines = sum (fmap lineTotal receiptLines)
  where
    lineTotal l = srlQtty l * srlPrice l * (1 - srlDiscount l / 100)
