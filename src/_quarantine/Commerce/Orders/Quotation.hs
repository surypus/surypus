-- | Quotation module - Commercial offers
module Commerce.Orders.Quotation
  ( Quotation   (..),
    QuotationStatus   (..),
    QuotationLine   (..),
    calcQuotationTotal,
    prop_quotationTotalNonNeg
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Test.QuickCheck

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

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary QuotationLine where
  arbitrary = do
    qtty <- suchThat arbitrary (> 0)
    price <- suchThat arbitrary (> 0)
    discount <- choose (0, 100 :: Double)
    pure $ QuotationLine 0 0 0 qtty price discount

prop_quotationTotalNonNeg :: QuotationLine -> Bool
prop_quotationTotalNonNeg ql = calcQuotationTotal ql >= 0
