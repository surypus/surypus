-- | ExtCode module - External codes
module System.Codes.ExtCode where

import Data.Int (Int64)
import Data.Text (Text)

-- | ExtCode - External system code
data ExtCode = ExtCode
  { ecId :: Int64,
    ecObjectType :: Int64,
    ecObjectId :: Int64,
    ecSystem :: Text,
    ecCode :: Text
  }
  deriving (Show, Eq)

-- | Get code
getCode :: ExtCode -> Text
getCode = ecCode
