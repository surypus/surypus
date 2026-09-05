-- | Config module - Configuration
module System.Config where

import Data.Int (Int64)
import Data.Text (Text)

-- | Config - Configuration
data Config = Config
  { cfgId :: Int64,
    cfgKey :: Text,
    cfgValue :: Text,
    cfgType :: ConfigType
  }
  deriving (Show, Eq)

data ConfigType = CTString | CTInt | CTBool | CTDouble
  deriving (Show, Eq)

-- | Get string value
getStringValue :: Config -> Text
getStringValue = cfgValue
