-- | TagObject module - Object tagging
module Inventory.TagObject where

import Data.Int (Int64)
import Data.Text (Text)

-- | Tag - Object tag
data Tag = Tag
  { tagId :: Int64,
    tagName :: Text,
    tagType :: TagType,
    tagColor :: Text
  }
  deriving (Show, Eq)

data TagType = TTGeneral | TTStatus | TTPriority | TTCustom
  deriving (Show, Eq)

-- | TagObject - Tag assignment to object
data TagObject = TagObject
  { toTagId :: Int64,
    toObjectType :: Int64,
    toObjectId :: Int64
  }
  deriving (Show, Eq)
