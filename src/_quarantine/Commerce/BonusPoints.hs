-- | BonusPoints module - Bonus points
module Commerce.BonusPoints  where

import Data.Int (Int64)
import Data.Time (Day)

-- | BonusPoints - Bonus points transaction
data BonusPoints = BonusPoints
  { bpId :: Int64,
    bpPersonId :: Int64,
    bpPoints :: Double,
    bpType :: BonusPointsType,
    bpDate :: Day
  }
  deriving (Show, Eq)

data BonusPointsType = BPTAccrual | BPTBurn | BPTExpired
  deriving (Show, Eq)

-- | Is accrual
isAccrual :: BonusPoints -> Bool
isAccrual bp = bpType bp == BPTAccrual
