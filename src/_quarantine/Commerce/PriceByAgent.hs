-- | PriceByAgent module - Agent-specific pricing
module Commerce.PriceByAgent  where

import Data.Int (Int64)

-- | PriceByAgent - Agent-specific price
data PriceByAgent = PriceByAgent
  { pbaId :: Int64,
    pbaGoodsId :: Int64,
    pbaAgentId :: Int64,
    pbaPrice :: Double
  }
  deriving (Show, Eq)

-- | Get agent price
getAgentPrice :: PriceByAgent -> Double
getAgentPrice = pbaPrice
