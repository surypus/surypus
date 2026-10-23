module Finance.Types (Money, RatePercent, RateFraction, calcVAT) where

import Data.Decimal (Decimal)
import Data.Decimal (toInteger, divide)
import Numeric (showFFloat)

newtype Money = Money { unMoney :: Decimal } deriving (Eq, Show)

data RatePercent = RatePercent { unRatePercent :: Decimal }
  deriving (Eq, Show)

data RateFraction = RateFraction { unRateFraction :: Decimal }
  deriving (Eq, Show)

rateToFraction :: RatePercent -> RateFraction
rateToFraction (RatePercent p) = RateFraction (p / 100)

calcVAT :: Money -> RatePercent -> Money
calcVAT (Money amount) rate = Money (amount * unRateFraction (rateToFraction rate))
