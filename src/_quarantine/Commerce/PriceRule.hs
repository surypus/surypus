-- | PriceRule module - Pricing rules
module Commerce.PriceRule  where

import Data.Int (Int64)
import Data.Text (Text)

-- | PriceRule - Dynamic pricing rule
data PriceRule = PriceRule
  { prId :: Int64,
    prName :: Text,
    prCondition :: Text, -- JSON
    prAdjustment :: Double, -- % or fixed
    prPriority :: Int,
    prEnabled :: Bool
  }
  deriving (Show, Eq)

-- | PriceRuleHistory - Price rule application history
data PriceRuleHistory = PriceRuleHistory
  { prhId :: Int64,
    prhRuleId :: Int64,
    prhGoodsId :: Int64,
    prhOldPrice :: Double,
    prhNewPrice :: Double,
    prhAppliedAt :: Int64
  }
  deriving (Show, Eq)
