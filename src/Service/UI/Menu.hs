-- | Menu module - Menu configuration
module Service.UI.Menu where

import Data.Int (Int64)
import Data.Text (Text)

-- | Menu - Menu configuration
data Menu = Menu
  { mnuId :: Int64,
    mnuName :: Text,
    mnuType :: MenuType,
    mnuParentId :: Maybe Int64
  }
  deriving (Show, Eq)

data MenuType = MTMain | MTContext | MTToolbar | MTPopup
  deriving (Show, Eq)

-- | MenuItem - Menu item
data MenuItem = MenuItem
  { miId :: Int64,
    miMenuId :: Int64,
    miName :: Text,
    miAction :: Text,
    miIcon :: Text,
    miShortcut :: Maybe Text,
    miOrder :: Int
  }
  deriving (Show, Eq)
