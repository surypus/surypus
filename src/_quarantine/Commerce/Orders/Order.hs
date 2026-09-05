-- | Order module - Sales orders
module Commerce.Orders.Order
  ( Order   (..),
    OrderStatus   (..),
    OrderLine   (..),
    LineStatus   (..),
    calcOrderTotal,
    calcLineTotal,
    prop_orderLineTotalNonNeg,
    prop_orderTotalNonNeg
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ type Discount = {v:Double | v >= 0 && v <= 100} @-}

-- | Order - Sales order
data Order = Order
  { ordId :: Int64,
    ordCode :: Text,
    ordClientId :: Int64,
    ordDate :: Day,
    ordDeliveryDate :: Maybe Day,
    ordStatus :: OrderStatus,
    ordFlags :: Int
  }
  deriving (Show, Eq)

data OrderStatus = OSDraft | OSConfirmed | OSInProgress | OSCompleted | OSCancelled
  deriving (Show, Eq)

-- | Order line
data OrderLine = OrderLine
  { olId :: Int64,
    olOrderId :: Int64,
    olGoodsId :: Int64,
    olQtty :: Double,
    olPrice :: Double,
    olDiscount :: Double,
    olStatus :: LineStatus
  }
  deriving (Show, Eq)

data LineStatus = LSPending | LSReserved | LSShipped | LSReturned
  deriving (Show, Eq)

-- | Calculate order total

{-@ calcOrderTotal :: [OrderLine] -> NonNeg @-}
calcOrderTotal :: [OrderLine] -> Double
calcOrderTotal orderLines = sum (fmap calcLineTotal orderLines)

-- {-@ calcLineTotal :: OrderLine -> NonNeg @-}
calcLineTotal :: OrderLine -> Double
calcLineTotal ol = olQtty ol * olPrice ol * (1 - olDiscount ol / 100)

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary OrderLine where
  arbitrary = do
    qtty <- suchThat arbitrary (> 0)
    price <- suchThat arbitrary (> 0)
    discount <- choose (0, 100 :: Double)
    pure $ OrderLine 0 0 0 qtty price discount LSPending

prop_orderLineTotalNonNeg :: OrderLine -> Bool
prop_orderLineTotalNonNeg ol = calcLineTotal ol >= 0

prop_orderTotalNonNeg :: Property
prop_orderTotalNonNeg =
  forAll (listOf arbitrary `suchThat` (not . null)) $ \orderLines ->
    calcOrderTotal orderLines >= 0
