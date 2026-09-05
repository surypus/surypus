-- | PaymentCard module - Payment cards
module Commerce.PaymentCard  where

import Data.Int (Int64)

-- | PaymentCard - Payment card
data PaymentCard = PaymentCard
  { pcId :: Int64,
    pcNumber :: String,
    pcHolderId :: Int64,
    pcExpiry :: String,
    pcType :: CardType
  }
  deriving (Show, Eq)

data CardType = CTVisa | CTMasterCard | CTMir | CTAmex
  deriving (Show, Eq)

-- | Mask card number
maskCard :: PaymentCard -> String
maskCard pc = replicate 12 '*' <> drop 12 (pcNumber pc)
