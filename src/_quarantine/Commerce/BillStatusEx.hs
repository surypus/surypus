-- | BillStatusEx module - Extended bill status
module Commerce.BillStatusEx  where

import Data.Int (Int64)

-- | BillStatusEx - Extended bill status
data BillStatusEx = BillStatusEx
  { bseId :: Int64,
    bseBillId :: Int64,
    bseStatus :: BillStatEx,
    bseChangedAt :: Int64,
    bseChangedBy :: Int64
  }
  deriving (Show, Eq)

data BillStatEx = BSEDraft | BSERegistered | BSEPosted | BSEAnnuled
  deriving (Show, Eq)

-- | Is bill posted
isPosted :: BillStatusEx -> Bool
isPosted b = bseStatus b == BSEPosted
