-- | TechCard module - Tech cards (тех. карты)
module Tech.TechCard where

import Data.Int (Int64)

-- | TechCard - Tech card
data TechCard = TechCard
  { tcId :: Int64,
    tcCode :: String,
    tcName :: String,
    tcProductId :: Int64,
    tcOutputQty :: Double,
    tcUnitId :: Int64
  }
  deriving (Show, Eq)

-- | Calculate output
getOutput :: TechCard -> Double
getOutput = tcOutputQty
