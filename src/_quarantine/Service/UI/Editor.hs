-- | Editor module - Text editor
module Service.UI.Editor where

import Data.Int (Int64)
import Data.Text (Text)

-- | EditorDocument - Editor document
data EditorDocument = EditorDocument
  { edId :: Int64,
    edName :: Text,
    edContent :: Text,
    edType :: EditorType,
    edOwnerId :: Int64
  }
  deriving (Show, Eq)

data EditorType = ETText | ETHTML | ETMarkdown | ETJSON | ETXML
  deriving (Show, Eq)

-- | EditorSession - Edit session
data EditorSession = EditorSession
  { esId :: Int64,
    esDocumentId :: Int64,
    esUserId :: Int64,
    esCursorPos :: Int,
    esSelection :: Maybe (Int, Int)
  }
  deriving (Show, Eq)
