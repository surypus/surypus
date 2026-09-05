-- | Contact module - Contact information
module HR.Contact where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text

-- | Contact - Contact info
data Contact = Contact
  { conId :: Int64,
    conPersonId :: Int64,
    conType :: ContactType,
    conValue :: Text,
    conPrimary :: Bool
  }
  deriving (Show, Eq)

data ContactType = CTPhone | CTEmail | CTAddress | CTURL
  deriving (Show, Eq)

-- | Validate contact
validateContact :: Contact -> Bool
validateContact c = not (Data.Text.null (conValue c))
