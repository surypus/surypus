-- | Dialog module - Dialog configuration
module Service.UI.Dialog where

import Data.Int (Int64)
import Data.Text (Text)

-- | Dialog - Dialog configuration
data Dialog = Dialog
  { dlgId :: Int64,
    dlgObjectType :: Int64,
    dlgName :: Text,
    dlgLayout :: Text, -- JSON
    dlgFlags :: Int
  }
  deriving (Show, Eq)

-- | DialogField - Dialog field
data DialogField = DialogField
  { dfId :: Int64,
    dfDialogId :: Int64,
    dfName :: Text,
    dfType :: FieldType,
    dfRequired :: Bool,
    dfDefault :: Maybe Text
  }
  deriving (Show, Eq)

data FieldType = FTString | FTInt | FTDouble | FTDate | FTBool | FTObject
  deriving (Show, Eq)
