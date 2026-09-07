{-# LANGUAGE OverloadedStrings #-}

-- | SmartReceipt module - Electronic receipts
module Retail.Receipts.SmartReceipt
  ( SmartReceipt   (..),
    PaymentType   (..),
    ReceiptStatus   (..),
    SmartReceiptLine   (..),
    calcReceiptTotal,
    prop_receiptTotalNonNeg
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime)
import Test.QuickCheck

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

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary SmartReceiptLine where
  arbitrary = do
    qtty <- suchThat arbitrary (> 0)
    price <- suchThat arbitrary (> 0)
    discount <- choose (0, 100 :: Double)
    tax <- choose (0, 100 :: Double)
    pure $ SmartReceiptLine 0 0 0 "" qtty price discount tax

prop_receiptTotalNonNeg :: Property
prop_receiptTotalNonNeg =
  forAll (listOf arbitrary `suchThat` (not . null)) $ \receiptLines ->
    calcReceiptTotal receiptLines >= 0
