-- | Order module - Sales orders
module Commerce.Orders.Order
  ( Order   (..),
    OrderStatus   (..),
    OrderLine   (..),
    LineStatus   (..),
    calcOrderTotal,
    calcLineTotal,
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

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
