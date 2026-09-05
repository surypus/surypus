-- | Person relations - Relationships between persons
module HR.Relation where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

data PersonRelation = PersonRelation
  { prId :: Int64,
    prPersonId :: Int64,
    prRelType :: RelationType,
    prRelatedPersonId :: Int64,
    prFlags :: Int
  }
  deriving (Show, Eq)

data RelationType
  = RTOwner
  | RTParent
  | RTSubsidiary
  | RTBranch
  | RTHead
  | RTAgent
  | RTContractor
  deriving (Show, Eq, Enum)

data PersonEvent = PersonEvent
  { peId :: Int64,
    pePersonId :: Int64,
    peType :: EventType,
    peDate :: Day,
    peDescription :: Text,
    peFlags :: Int
  }
  deriving (Show, Eq)

data EventType
  = ETRegistration
  | ETStatusChange
  | ETCategoryChange
  | ETMerge
  | ETSplit
  deriving (Show, Eq, Enum)