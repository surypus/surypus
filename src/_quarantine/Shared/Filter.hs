-- | Filter module - Data filters
module Shared.Filter where

import Data.Int (Int64)
import Data.Text (Text)

-- | Filter - Data filter
data Filter = Filter
  { flId :: Int64,
    flName :: Text,
    flObjectType :: Int64,
    flDefinition :: Text, -- JSON
    flOwnerId :: Int64
  }
  deriving (Show, Eq)

-- | FilterPreset - Saved filter preset
data FilterPreset = FilterPreset
  { fpId :: Int64,
    fpFilterId :: Int64,
    fpName :: Text,
    fpValues :: Text -- JSON
  }
  deriving (Show, Eq)
