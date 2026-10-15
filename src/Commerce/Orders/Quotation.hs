-- | Quotation module - Commercial offers
module Commerce.Orders.Quotation
  ( Quotation   (..),
    QuotationStatus   (..),
    QuotationLine   (..),
    calcQuotationTotal,
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ type Discount = {v:Double | v >= 0 && v <= 100} @-}

-- | Quotation - Commercial offer
data Quotation = Quotation
  { qotId :: Int64,
    qotCode :: Text,
    qotClientId :: Int64,
    qotDate :: Day,
    qotValidTill :: Maybe Day,
    qotStatus :: QuotationStatus,
    qotFlags :: Int
  }
  deriving (Show, Eq)

data QuotationStatus = QSDraft | QSSent | QSAccepted | QSRejected | QSExpired
  deriving (Show, Eq)

-- | Quotation line
data QuotationLine = QuotationLine
  { qlId :: Int64,
    qlQuotationId :: Int64,
    qlGoodsId :: Int64,
    qlQtty :: Double,
    qlPrice :: Double,
    qlDiscount :: Double
  }
  deriving (Show, Eq)

-- | Calculate total

{-@ calcQuotationTotal :: QuotationLine -> NonNeg @-}
calcQuotationTotal :: QuotationLine -> Double
calcQuotationTotal ql = qlQtty ql * qlPrice ql * (1 - qlDiscount ql / 100)
