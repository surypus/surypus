-- | PersonEx module - Extended person
module HR.PersonEx where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T

-- | PersonEx - Extended person
data PersonEx = PersonEx
  { peId :: Int64,
    peCode :: Text,
    peName :: Text,
    peINN :: Text,
    peKPP :: Text,
    peType :: PersonType2
  }
  deriving (Show, Eq)

data PersonType2 = PT2_Company | PT2_Individual | PT2_Entrepreneur
  deriving (Show, Eq)

-- | Validate INN
validateINN :: PersonEx -> Bool
validateINN p = T.length (peINN p) == 10 || T.length (peINN p) == 12
