-- | UhttStore module - Universe-HTT online store
module External.UHTT.UhttStore where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | UhttStore - Online store
data UhttStore = UhttStore
  { usId :: Int64,
    usName :: Text,
    usURL :: Text,
    usAPIKey :: Text,
    usStatus :: UhttStatus
  }
  deriving (Show, Eq)

data UhttStatus = USActive | USInactive
  deriving (Show, Eq)

-- | UhttOrder - Order from store
data UhttOrder = UhttOrder
  { uoId :: Int64,
    uoStoreId :: Int64,
    uoExternalId :: Text,
    uoDate :: Day,
    uoStatus :: UhttOrderStatus,
    uoTotal :: Double
  }
  deriving (Show, Eq)

data UhttOrderStatus = UOSNew | UOSProcessing | UOSShipped | UOSDelivered
  deriving (Show, Eq)
