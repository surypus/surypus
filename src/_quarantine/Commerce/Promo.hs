-- | Promo module - Promotions
module Commerce.Promo  where

import Data.Int (Int64)
import Data.Time (Day)

-- | Promo - Promotion
data Promo = Promo
  { pmId :: Int64,
    pmCode :: String,
    pmName :: String,
    pmStartDate :: Day,
    pmEndDate :: Day,
    pmDiscount :: Double
  }
  deriving (Show, Eq)

-- | Is active
isPromoActive :: Promo -> Day -> Bool
isPromoActive pm today = today >= pmStartDate pm && today <= pmEndDate pm
