-- | StyloQ module - Stylo-Q secure messenger
module Inventory.StyloQ where

import Data.Int (Int64)
import Data.Text (Text)

-- | StyloQBinery - Stylo-Q binary data
data StyloQBinery = StyloQBinery
  { sqbId :: Int64,
    sqbGuid :: Text, -- UUID
    sqbData :: Text, -- Base64
    sqbFlags :: Int
  }
  deriving (Show, Eq)

-- | StyloQContact - Stylo-Q contact
data StyloQContact = StyloQContact
  { sqcId :: Int64,
    sqcPublicKey :: Text,
    sqcName :: Text,
    sqcFlags :: Int
  }
  deriving (Show, Eq)
