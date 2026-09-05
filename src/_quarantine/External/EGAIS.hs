-- | EGAIS module - Russian alcohol tracking system
module External.EGAIS where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Fix: ET_ prefix is reserved
data EgaisType2 = Waybill2 | ActWriteOff2 | ActTurnover2
  deriving (Show, Eq)

-- | EGAIS shipment
data EgaisShipment = EgaisShipment
  { esId :: Int64,
    esBillId :: Int64,
    esOrgId :: Int64,
    esDate :: Day,
    esType :: EgaisType2,
    esStatus :: EgaisStatus,
    esReplyId :: Maybe Text
  }
  deriving (Show, Eq)

data EgaisType = ETWaybill | ETActWriteOff | ETActTurnover
  deriving (Show, Eq)

data EgaisStatus = ESPending | ESSent | ESAccepted | ESRejected
  deriving (Show, Eq)

-- | EGAIS product info
data EgaisProduct = EgaisProduct
  { epId :: Int64,
    epAlcCode :: Text, -- Alcohol code
    epName :: Text,
    epVolume :: Double,
    epStrength :: Double,
    epProducerId :: Int64
  }
  deriving (Show, Eq)

-- | Validate EGAIS waybill
validateEgaisShipment :: EgaisShipment -> Bool
validateEgaisShipment es = esStatus es /= ESRejected
