-- | Notification module - Push notifications
module Infrastructure.Notification where

import Data.Int (Int64)
import Data.Text (Text)

-- | Notification - Push notification
data Notification = Notification
  { nId :: Int64,
    nUserId :: Int64,
    nTitle :: Text,
    nBody :: Text,
    nData :: Text, -- JSON
    nStatus :: NotificationStatus,
    nCreatedAt :: Int64
  }
  deriving (Show, Eq)

data NotificationStatus = NSPending | NSSent | NSDelivered | NSRead | NSFailed
  deriving (Show, Eq)

-- | NotificationTemplate - Notification template
data NotificationTemplate = NotificationTemplate
  { ntId :: Int64,
    ntName :: Text,
    ntTitle :: Text,
    ntBody :: Text,
    ntVariables :: Text -- JSON
  }
  deriving (Show, Eq)
