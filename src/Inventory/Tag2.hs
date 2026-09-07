-- | Tag2 module - Tags
module Inventory.Tag2 where

import Data.Int (Int64)

-- | Tag2 - Tag
data Tag2 = Tag2
  { t2Id :: Int64,
    t2Name :: String,
    t2Color :: String,
    t2CategoryId :: Int64
  }
  deriving (Show, Eq)

-- | Get name
getTagName :: Tag2 -> String
getTagName = t2Name
