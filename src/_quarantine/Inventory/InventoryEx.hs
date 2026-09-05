-- | InventoryEx module - Extended inventory
module Inventory.InventoryEx where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | InventoryEx - Extended inventory
data InventoryEx = InventoryEx
  { invId :: Int64,
    invCode :: Text,
    invDate :: Day,
    invLocationId :: Int64,
    invStatus :: InvStatus
  }
  deriving (Show, Eq)

data InvStatus = ISDraft | ISInProgress | ISCompleted | ISCancelled
  deriving (Show, Eq)

-- | Is inventory active
isActive :: InventoryEx -> Bool
isActive i = invStatus i == ISInProgress
