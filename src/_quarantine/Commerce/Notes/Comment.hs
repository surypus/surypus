-- | Comment module - Comments
module Commerce.Notes.Comment  where

import Data.Int (Int64)
import Data.Time (Day)

-- | Comment - Comment
data Comment = Comment
  { comId :: Int64,
    comObjectType :: Int64,
    comObjectId :: Int64,
    comUserId :: Int64,
    comText :: String,
    comDate :: Day
  }
  deriving (Show, Eq)

-- | Get comment text
getText :: Comment -> String
getText = comText
