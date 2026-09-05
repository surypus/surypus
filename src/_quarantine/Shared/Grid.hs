-- | Grid module - Data grid
module Shared.Grid where

import Data.Int (Int64)
import Data.Text (Text)

-- | GridColumn - Grid column
data GridColumn = GridColumn
  { gcId :: Int64,
    gcName :: Text,
    gcField :: Text,
    gcWidth :: Int,
    gcAlign :: AlignType,
    gcSortable :: Bool
  }
  deriving (Show, Eq)

data AlignType = ATLeft | ATCenter | ATRight
  deriving (Show, Eq)

-- | GridView - Grid view configuration
data GridView = GridView
  { gvId :: Int64,
    gvObjectType :: Int64,
    gvName :: Text,
    gvColumns :: Text, -- JSON
    gvFlags :: Int
  }
  deriving (Show, Eq)
