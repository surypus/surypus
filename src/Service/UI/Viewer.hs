-- | Viewer module - Data viewer
module Service.UI.Viewer where

import Data.Int (Int64)
import Data.Text (Text)

-- | ViewerView - Viewer view
data ViewerView = ViewerView
  { vvId :: Int64,
    vvObjectType :: Int64,
    vvName :: Text,
    vvConfig :: Text -- JSON
  }
  deriving (Show, Eq)

-- | ViewerFilter - Viewer filter
data ViewerFilter = ViewerFilter
  { vfId :: Int64,
    vfViewId :: Int64,
    vfField :: Text,
    vfOperation :: FilterOp,
    vfValue :: Text
  }
  deriving (Show, Eq)

data FilterOp = FOEquals | FOContains | FOGreater | FOLess | FOBetween
  deriving (Show, Eq)
