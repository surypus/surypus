-- | Shipment module - Shipments
module Commerce.Shipment  where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Shipment - Shipment record
data Shipment = Shipment
  { shpId :: Int64,
    shpCode :: Text,
    shpDate :: Day,
    shpOrderId :: Int64,
    shpStatus :: ShipmentStatus,
    shpCarrier :: Maybe Text
  }
  deriving (Show, Eq)

data ShipmentStatus = SSPending | SSPacked | SSShipped | SSDelivered
  deriving (Show, Eq)

-- | Is shipment delivered
isDelivered :: Shipment -> Bool
isDelivered s = shpStatus s == SSDelivered
