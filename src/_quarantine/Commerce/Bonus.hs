-- | Bonus module - Bonus system
module Commerce.Bonus  where

import Data.Int (Int64)
import Data.Text (Text)

-- | BonusProgram - Bonus program
data BonusProgram = BonusProgram
  { bpId :: Int64,
    bpName :: Text,
    bpAccrualRate :: Double, -- % of purchase
    bpBurnRate :: Double, -- points per currency
    bpValidityDays :: Int
  }
  deriving (Show, Eq)

-- | BonusAccount - Customer bonus account
data BonusAccount = BonusAccount
  { baId :: Int64,
    baPersonId :: Int64,
    baProgramId :: Int64,
    baPoints :: Double,
    baTotalAccrued :: Double,
    baTotalBurned :: Double
  }
  deriving (Show, Eq)
