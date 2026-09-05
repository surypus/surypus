-- | Event module - Event logging
module System.Event where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime, getCurrentTime)

-- | Event - System event
data Event = Event
  { evId :: Int64,
    evType :: EventType,
    evObjType :: Int64,
    evObjId :: Int64,
    evUserId :: Int64,
    evTime :: UTCTime,
    evMessage :: Text,
    evFlags :: Int
  }
  deriving (Show, Eq)

data EventType = ETInfo | ETWarning | ETError | ETAudit
  deriving (Show, Eq)

-- | EventSubscription - Event subscription
data EventSubscription = EventSubscription
  { esId :: Int64,
    esUserId :: Int64,
    esEventType :: EventType,
    esWebhookId :: Maybe Int64,
    esFlags :: Int
  }
  deriving (Show, Eq)

-- | Log event - creates a new event with current timestamp
logEvent :: EventType -> Int64 -> Int64 -> Int64 -> Text -> IO Event
logEvent et ot oid uid msg = do
  now <- getCurrentTime
  pure $ Event 0 et ot oid uid now msg 0
