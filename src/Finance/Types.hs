module Finance.Types (Money (..), RatePercent (..), RateFraction (..), calcVAT, AccTurn (..)) where

import Data.Decimal (Decimal)
import Data.Time (Day)
import Numeric (showFFloat)
import Data.Int (Int64)

newtype Money = Money { unMoney :: Decimal } deriving (Eq, Show)

data RatePercent = RatePercent { unRatePercent :: Decimal }
  deriving (Eq, Show)

data RateFraction = RateFraction { unRateFraction :: Decimal }
  deriving (Eq, Show)

rateToFraction :: RatePercent -> RateFraction
rateToFraction (RatePercent p) = RateFraction (p / 100)

calcVAT :: Money -> RatePercent -> Money
calcVAT (Money amount) rate = Money (amount * unRateFraction (rateToFraction rate))

-- | Accounting turn - single accounting entry (debit/credit)
data AccTurn = AccTurn
  { atId    :: !Int
  , atAcctId :: !Int
  , atArId   :: !Int
  , atDate   :: !Day
  , atAmount :: !Double
  , atCurId  :: !Int
  , atCurRate :: !Double
  , atFlags  :: !Int
  , atBillId :: !Int64
  , atCorrId :: !Int
  , atDbtAmt :: !Double
  , atCrdAmt :: !Double
  } deriving (Show, Eq)
