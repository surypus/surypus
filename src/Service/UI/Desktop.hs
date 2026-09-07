-- | Desktop module - User desktop
module Service.UI.Desktop where

import Data.Int (Int64)
import Data.Text (Text)

-- | Desktop - User desktop layout
data Desktop = Desktop
  { dtId :: Int64,
    dtUserId :: Int64,
    dtName :: Text,
    dtLayout :: Text, -- JSON
    dtFlags :: Int
  }
  deriving (Show, Eq)

-- | DesktopView - Desktop view
data DesktopView = DesktopView
  { dvId :: Int64,
    dvDesktopId :: Int64,
    dvObjectType :: Int64,
    dvViewId :: Int64,
    dvPosition :: Text -- JSON {x,y,w,h}
  }
  deriving (Show, Eq)
