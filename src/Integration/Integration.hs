-- | Integration module - External integrations
module Integration.Integration where

import Data.Int (Int64)
import Data.Text (Text)

-- | EDIProvider - EDI exchange provider
data EDIProvider = EDIProvider
  { ediId :: Int64,
    ediCode :: Text,
    ediName :: Text,
    ediURL :: Text,
    ediLogin :: Text,
    ediFlags :: Int
  }
  deriving (Show, Eq)

-- | Webhook - Webhook configuration
data Webhook = Webhook
  { whId :: Int64,
    whURL :: Text,
    whEvent :: WebhookEvent,
    whSecret :: Text,
    whFlags :: Int
  }
  deriving (Show, Eq)

data WebhookEvent = WEBillCreated | WEBillPosted | WEBillChanged | WEGoodsChanged
  deriving (Show, Eq)

-- | SMSAccount - SMS provider
data SMSAccount = SMSAccount
  { smsId :: Int64,
    smsName :: Text,
    smsProvider :: Text,
    smsLogin :: Text,
    smsPassword :: Text
  }
  deriving (Show, Eq)

-- | InternetAccount - Mail account
data InternetAccount = InternetAccount
  { iaId :: Int64,
    iaName :: Text,
    iaServer :: Text,
    iaLogin :: Text,
    iaPassword :: Text,
    iaPort :: Int,
    iaSSL :: Bool
  }
  deriving (Show, Eq)
