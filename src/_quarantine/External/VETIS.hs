-- | VETIS module - Russian veterinary tracking system
module External.VETIS where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | VETIS entity
data VetisEntity = VetisEntity
  { veId :: Int64,
    veGuid :: Text, -- UUID
    veType :: VetisType,
    veName :: Text,
    veStatus :: VetisStatus
  }
  deriving (Show, Eq)

data VetisType = VTProducer | VTStorage | VTTransport | VTRecipient
  deriving (Show, Eq)

data VetisStatus = VSActive | VSArchived
  deriving (Show, Eq)

-- | VETIS movement
data VetisMovement = VetisMovement
  { vmId :: Int64,
    vmFromGuid :: Text,
    vmToGuid :: Text,
    vmDate :: Day,
    vmDocId :: Int64,
    vmStatus :: VetisStatus
  }
  deriving (Show, Eq)

-- | Check if VETIS entity is active
isVetisActive :: VetisEntity -> Bool
isVetisActive ve = veStatus ve == VSActive
