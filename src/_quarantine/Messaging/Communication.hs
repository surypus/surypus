-- | Communication module - Messaging
module Messaging.Communication  where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)

-- | Message - Internal message
data Message = Message
  { msgId :: Int64,
    msgFromId :: Int64,
    msgToId :: Int64,
    msgSubject :: Text,
    msgBody :: Text,
    msgSentAt :: UTCTime,
    msgReadAt :: Maybe UTCTime
  }
  deriving (Show, Eq)

-- | Email - Email message
data Email = Email
  { emId :: Int64,
    emFrom :: Text,
    emTo :: Text,
    emSubject :: Text,
    emBody :: Text,
    emSentAt :: UTCTime,
    emStatus :: EmailStatus
  }
  deriving (Show, Eq)

data EmailStatus = EMPending | EMSent | EMFailed
  deriving (Show, Eq)

-- | EAddress - Electronic address
data EAddress = EAddress
  { eaId :: Int64,
    eaPersonId :: Int64,
    eaType :: EAddrType,
    eaAddress :: Text,
    eaFlags :: Int
  }
  deriving (Show, Eq)

data EAddrType = EAEmail | EAPhone | EATelegram | EAWhatsApp
  deriving (Show, Eq)
