{-# LANGUAGE OverloadedStrings #-}

-- | Agent module - Agents
module DAL.Agent
  ( Agent   (..),
    calcCommission,
  ) where

import Data.Int (Int64)
import Data.Text (Text)

{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ type CommissionRate = {v:Double | v >= 0 && v <= 100} @-}

-- | Agent - Sales agent
data Agent = Agent
  { agtId :: Int64,
    agtCode :: Text,
    agtName :: Text,
    agtCommission :: Double,
    agtRegion :: Text
  }
  deriving (Show, Eq)

-- | Calculate commission

{-@ calcCommission :: Agent -> sales:NonNeg -> NonNeg @-}
calcCommission :: Agent -> Double -> Double
calcCommission a sales = sales * agtCommission a / 100
