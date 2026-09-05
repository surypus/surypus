-- | Transport module - Logistics
module Logistics.Transport.Transport where

import Data.Int (Int64)
import Data.Text (Text)

-- | Transport - Vehicle
data Transport = Transport
  { trId :: Int64,
    trCode :: Text,
    trRegNum :: Text, -- Registration number
    trModelId :: Int64,
    trDriverId :: Int64,
    trCapacity :: Double,
    trFlags :: Int
  }
  deriving (Show, Eq)

-- | TranspModel - Vehicle model
data TranspModel = TranspModel
  { tmId :: Int64,
    tmCode :: Text,
    tmName :: Text,
    tmBrand :: Text,
    tmCapacity :: Double
  }
  deriving (Show, Eq)

-- | FreightPackage - Cargo package
data FreightPackage = FreightPackage
  { fpId :: Int64,
    fpTypeId :: Int64,
    fpCode :: Text,
    fpWeight :: Double,
    fpVolume :: Double
  }
  deriving (Show, Eq)
