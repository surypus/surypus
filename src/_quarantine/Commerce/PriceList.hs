-- | PriceList module - Price lists
module Commerce.PriceList  where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | PriceList - Price list
data PriceList = PriceList
  { plId :: Int64,
    plCode :: Text,
    plName :: Text,
    plCurrencyId :: Int64,
    plValidFrom :: Day,
    plValidTo :: Maybe Day
  }
  deriving (Show, Eq)

-- | Is price list valid
isPriceListValid :: PriceList -> Day -> Bool
isPriceListValid pl today = today >= plValidFrom pl && maybe True (today <=) (plValidTo pl) -- hlint: ignore
