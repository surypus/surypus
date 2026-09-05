-- | Component module - UI components
module Production.Components.Component where

import Data.Int (Int64)
import Data.Text (Text)

-- | Component - UI component
data Component = Component
  { cmpId :: Int64,
    cmpName :: Text,
    cmpType :: ComponentType,
    cmpConfig :: Text -- JSON
  }
  deriving (Show, Eq)

data ComponentType = CTButton | CTInput | CTTable | CTChart | CTForm
  deriving (Show, Eq)

-- | ComponentLibrary - Component library
data ComponentLibrary = ComponentLibrary
  { clId :: Int64,
    clName :: Text,
    clVersion :: Text,
    clComponents :: Text -- JSON array
  }
  deriving (Show, Eq)
