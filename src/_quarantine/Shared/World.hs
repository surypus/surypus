-- | World module - Geographic data
module Shared.World where

import Data.Int (Int64)
import Data.Text (Text)

-- | World object - Geographic entity
data World = World
  { wldId :: Int64,
    wldName :: Text,
    wldType :: WorldType,
    wldParentId :: Maybe Int64,
    wldCountry :: Text,
    wldRegion :: Text,
    wldCity :: Text,
    wldAddress :: Text
  }
  deriving (Show, Eq)

data WorldType = WTCountry | WTRegion | WTCity | WTStreet | WTBuilding
  deriving (Show, Eq)

-- | Geo tracking
data Geotracking = Geotracking
  { gtId :: Int64,
    gtObjectType :: Int64,
    gtObjectId :: Int64,
    gtLat :: Double,
    gtLon :: Double,
    gtTimestamp :: Int64
  }
  deriving (Show, Eq)
