-- | Settings module - System configuration
module System.Settings where

import Data.Int (Int64)
import Data.Text (Text)

-- | Global settings
data Settings = Settings
  { setId :: Int64,
    setKey :: Text,
    setValue :: Text,
    setType :: SettingType,
    setFlags :: Int
  }
  deriving (Show, Eq)

data SettingType = STString | STInt | STBool | STDouble | ST_JSON
  deriving (Show, Eq)

-- | Company info
data Company = Company
  { compId :: Int64,
    compName :: Text,
    compINN :: Text,
    compKPP :: Text,
    compAddress :: Text,
    compPhone :: Text,
    compEmail :: Text,
    compDirector :: Text
  }
  deriving (Show, Eq)

-- | Database division
data DbDiv = DbDiv
  { dbdId :: Int64,
    dbdName :: Text,
    dbdSymb :: Text,
    dbdFlags :: Int
  }
  deriving (Show, Eq)
