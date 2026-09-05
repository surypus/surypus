-- | GiftCard module - Gift cards
module Commerce.GiftCard  where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | GiftCard - Gift card
data GiftCard = GiftCard
  { gcId :: Int64,
    gcCode :: Text,
    gcInitialValue :: Double,
    gcBalance :: Double,
    gcIssueDate :: Day,
    gcExpireDate :: Maybe Day,
    gcStatus :: GiftCardStatus
  }
  deriving (Show, Eq)

data GiftCardStatus = GCSActive | GCSUsed | GCSExpired | GSCancelled
  deriving (Show, Eq)

-- | GiftCardOperation - Usage history
data GiftCardOperation = GiftCardOperation
  { gcoId :: Int64,
    gcoCardId :: Int64,
    gcoType :: GCOpType,
    gcoAmount :: Double,
    gcoDate :: Day,
    gcoOrderId :: Maybe Int64
  }
  deriving (Show, Eq)

data GCOpType = GCTIssue | GCTLoad | GCTPayment | GCTRefund
  deriving (Show, Eq)

-- | Check if card is valid
isGiftCardValid :: GiftCard -> Day -> Bool
isGiftCardValid gc today =
  gcStatus gc == GCSActive
    && case gcExpireDate gc of
      Nothing -> True
      Just expiryDate -> today <= expiryDate
