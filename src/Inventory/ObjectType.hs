-- | ObjectType module - Object types
module Inventory.ObjectType where

import Data.Int (Int64)
import Data.Text (Text)

-- | ObjectType - Object type definition
data ObjectType = ObjectType
  { otId :: Int64,
    otName :: Text,
    otCode :: Text,
    otTableName :: Text,
    otFlags :: Int
  }
  deriving (Show, Eq)

-- | ObjectProperty - Object property
data ObjectProperty = ObjectProperty
  { opId :: Int64,
    opObjectTypeId :: Int64,
    opName :: Text,
    opType :: PropertyType,
    opRequired :: Bool
  }
  deriving (Show, Eq)

data PropertyType = PropString | PropInt | PropDouble | PropBool | PropDate | PropObject
  deriving (Show, Eq)
