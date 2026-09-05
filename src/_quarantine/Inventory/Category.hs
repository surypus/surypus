-- | Category module - Product categories
module Inventory.Category where

import Data.Int (Int64)
import Data.Text (Text)

-- | Category - Product category
data Category = Category
  { catId :: Int64,
    catName :: Text,
    catParentId :: Maybe Int64,
    catImage :: Text,
    catFlags :: Int
  }
  deriving (Show, Eq)

-- | Category property
data CategoryProp = CategoryProp
  { cpId :: Int64,
    cpCategoryId :: Int64,
    cpName :: Text,
    cpType :: PropType,
    cpRequired :: Bool
  }
  deriving (Show, Eq)

data PropType = PTString | PTInt | PTDouble | PTBool | PTEnum
  deriving (Show, Eq)
