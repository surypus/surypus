-- | Transfer module - Stock transfers (corresponds to TransferTbl in C<>)
module Logistics.Transfer
  ( Transfer   (..),
    TransferStatus   (..),
    TransferFlags   (..),
    TransferLine   (..),
    isTransferComplete,
    isTransferLineComplete,
    getRemainingQtty,
    calcTransferAmount,
    validateTransferLine,
    prop_remaining_nonnegative,
    prop_received_bounded,
    prop_transferAmountNonNeg
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}

-- ============================================================================
-- TRANSFER TYPES
-- ============================================================================

-- | Transfer - Stock transfer between warehouses
data Transfer = Transfer
  { trId :: Int64,
    trCode :: Text,
    trDate :: Day,
    trSourceLocId :: Int64, -- Source location (откуда)
    trDestLocId :: Int64, -- Destination location (куда)
    trBillId :: Int64, -- Linked bill ID
    trStatus :: TransferStatus,
    trFlags :: Int
  }
  deriving (Show, Eq)

-- | Transfer status
data TransferStatus = TSDraft | TSSent | TSReceived | TSCancelled
  deriving (Show, Eq)

-- | Transfer flags - corresponds to TRANSF_*
data TransferFlags = TransferFlags
  { tfAutoCreated :: Bool, -- TRANSF_AUTOCREATED
    tfAccepted :: Bool, -- TRANSF_ACCEPT
    tfInventory :: Bool -- TRANSF_INVENTORY
  }
  deriving (Show, Eq)

-- | Transfer line - corresponds to TransferTbl::Fignt
data TransferLine = TransferLine
  { tlId :: Int64,
    tlTransferId :: Int64,
    tlGoodsId :: Int64,
    tlSourceLotId :: Int64, -- Source lot (from which lot)
    tlDestLotId :: Int64, -- Destination lot (to which lot)
    tlQtty :: Double, -- Transfer quantity
    tlSentQtty :: Double, -- Sent quantity
    tlReceivedQtty :: Double, -- Received quantity
    tlPrice :: Double, -- Price
    tlCost :: Double, -- Cost
    tlFlags :: Int
  }
  deriving (Show, Eq)

-- ============================================================================
-- TRANSFER FUNCTIONS
-- ============================================================================

-- | Check if transfer is complete (all goods received)
isTransferComplete :: Transfer -> Bool
isTransferComplete t = trStatus t == TSReceived

-- | Check if transfer line is fully received
isTransferLineComplete :: TransferLine -> Bool
isTransferLineComplete tl = tlReceivedQtty tl >= tlQtty tl

-- | Get remaining quantity to receive
getRemainingQtty :: TransferLine -> Double
getRemainingQtty tl = max 0 (tlQtty tl - tlReceivedQtty tl)

-- | Calculate transfer amount

{-@ calcTransferAmount :: TransferLine -> NonNeg @-}
calcTransferAmount :: TransferLine -> Double
calcTransferAmount tl = tlQtty tl * tlPrice tl

-- | Validate transfer line
validateTransferLine :: TransferLine -> Bool
validateTransferLine tl =
  tlQtty tl >= 0 && tlSentQtty tl >= 0 && tlReceivedQtty tl >= 0

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

-- | Property: Remaining quantity is non-negative
prop_remaining_nonnegative :: TransferLine -> Property
prop_remaining_nonnegative tl =
  property (getRemainingQtty tl >= 0)

-- | Property: Received quantity cannot exceed transfer quantity
prop_received_bounded :: TransferLine -> Property
prop_received_bounded tl =
  property (tlReceivedQtty tl <= tlQtty tl)

-- | Property: Transfer amount is non-negative
prop_transferAmountNonNeg :: TransferLine -> Bool
prop_transferAmountNonNeg tl = calcTransferAmount tl >= 0

instance Arbitrary TransferLine where
  arbitrary = do
    qtty <- suchThat arbitrary (>= 0)
    sent <- choose (0, qtty)
    recvd <- choose (0, sent)
    price <- suchThat arbitrary (>= 0)
    cost <- suchThat arbitrary (>= 0)
    pure $ TransferLine 0 0 0 0 0 qtty sent recvd price cost 0
