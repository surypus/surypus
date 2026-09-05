-- | Validator module - Data validation
module System.Validator where

import Data.Int (Int64)
import Data.Text (Text)

-- | ValidationRule - Validation rule
data ValidationRule = ValidationRule
  { vrId :: Int64,
    vrObjectType :: Int64,
    vrField :: Text,
    vrType :: ValidationType,
    vrParams :: Text, -- JSON
    vrMessage :: Text
  }
  deriving (Show, Eq)

data ValidationType = VTRequired | VTMinLength | VTMaxLength | VTPattern | VTRange | VTCustom
  deriving (Show, Eq)

-- | ValidationResult - Validation result
data ValidationResult = ValidationResult
  { vrValid :: Bool,
    vrErrors :: [Text]
  }
  deriving (Show, Eq)
