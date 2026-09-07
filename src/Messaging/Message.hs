-- | Message module - Messages
module Messaging.Message  where

import Data.Int (Int64)
import Data.Time (Day)

-- | Message - Message
data Message = Message
  { msgId :: Int64,
    msgFromId :: Int64,
    msgToId :: Int64,
    msgSubject :: String,
    msgBody :: String,
    msgDate :: Day,
    msgRead :: Bool
  }
  deriving (Show, Eq)

-- | Is unread
isUnread :: Message -> Bool
isUnread m = not (msgRead m)
