-- | TagValue module - Tag values
module Inventory.TagValue where

import Data.Int (Int64)
import Data.Text (Text)

-- | TagValue - Tag value assignment
data TagValue = TagValue
  { tvId :: Int64,
    tvTagId :: Int64,
    tvObjectType :: Int64,
    tvObjectId :: Int64,
    tvValue :: Text
  }
  deriving (Show, Eq)

-- | Get tags for object
getTagsForObject :: [TagValue] -> Int64 -> [TagValue]
getTagsForObject tags objId = filter (\t -> tvObjectId t == objId) tags
