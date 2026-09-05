-- | PriceByTime module - Time-based pricing
module Commerce.PriceByTime  where

import Data.Int (Int64)
import Data.Time (Day)

-- | PriceByTime - Time-based price
data PriceByTime = PriceByTime
  { pbtId :: Int64,
    pbtGoodsId :: Int64,
    pbtPrice :: Double,
    pbtStartDate :: Day,
    pbtEndDate :: Day
  }
  deriving (Show, Eq)

-- | Get price
getTimePrice :: PriceByTime -> Double
getTimePrice = pbtPrice
