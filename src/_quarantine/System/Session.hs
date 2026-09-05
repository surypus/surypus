-- | Session module - User sessions
module System.Session where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)

-- | Session - User session
data Session = Session
  { sessId :: Int64,
    sessUserId :: Int64,
    sessToken :: Text,
    sessIP :: Text,
    sessStart :: UTCTime,
    sessExpires :: UTCTime,
    sessFlags :: Int
  }
  deriving (Show, Eq)

-- | SessionLog - Session history
data SessionLog = SessionLog
  { slId :: Int64,
    slUserId :: Int64,
    slAction :: SessionAction,
    slTimestamp :: UTCTime,
    slIP :: Text
  }
  deriving (Show, Eq)

data SessionAction = SALogin | SALogout | SAFailed | SAPasswordChange
  deriving (Show, Eq)
