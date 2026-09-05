-- | Preorder module - Preorders
module Commerce.Orders.Preorder where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Preorder - Preorder
data Preorder = Preorder
  { poId :: Int64,
    poCode :: Text,
    poDate :: Day,
    poCustomerId :: Int64,
    poExpectedDate :: Day,
    poStatus :: PreorderStatus
  }
  deriving (Show, Eq)

data PreorderStatus = POSPending | POSConfirmed | POSShipped | POSCompleted | POSCancelled
  deriving (Show, Eq)

-- | Is preorder active
isPreorderActive :: Preorder -> Bool
isPreorderActive p = poStatus p == POSPending || poStatus p == POSConfirmed
