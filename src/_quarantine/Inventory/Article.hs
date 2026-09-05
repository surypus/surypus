-- | Article module - Articles
module Inventory.Article where

import Data.Int (Int64)

-- | Article - Article
data Article = Article
  { artId :: Int64,
    artCode :: String,
    artName :: String,
    artCategoryId :: Int64,
    artContent :: String
  }
  deriving (Show, Eq)

-- | Get preview
getPreview :: Article -> String
getPreview a = take 100 (artContent a)
