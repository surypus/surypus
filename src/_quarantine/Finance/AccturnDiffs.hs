-- | AccturnDiffs module - Accounting turn differences
module Finance.AccturnDiffs where

import Data.Int (Int64)

-- | AccturnDiffs - Accounting turn differences
data AccturnDiffs = AccturnDiffs
  { adId :: Int64,
    adTurnId :: Int64,
    adAccId :: Int64,
    adAmount :: Double,
    adCurId :: Int64
  }
  deriving (Show, Eq)

-- | Get amount
getAmount :: AccturnDiffs -> Double
getAmount = adAmount
