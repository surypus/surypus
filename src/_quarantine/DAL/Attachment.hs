-- | Attachment module - File attachments
module DAL.Attachment  where

import Data.Int (Int64)
import Data.Text (Text)

-- | Attachment - File attachment
data Attachment = Attachment
  { attId :: Int64,
    attOwnerType :: Int64, -- Object type
    attOwnerId :: Int64, -- Object ID
    attName :: Text,
    attPath :: Text,
    attSize :: Int64,
    attMimeType :: Text,
    attHash :: Text, -- SHA256
    attFlags :: Int
  }
  deriving (Show, Eq)

-- | Tag - Object tag
data Tag = Tag
  { tagId :: Int64,
    tagName :: Text,
    tagType :: Int
  }
  deriving (Show, Eq)

-- | TagObject - Tag assignment
data TagObject = TagObject
  { toTagId :: Int64,
    toObjType :: Int64,
    toObjId :: Int64
  }
  deriving (Show, Eq)
