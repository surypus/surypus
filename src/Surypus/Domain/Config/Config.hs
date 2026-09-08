{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
module Surypus.Domain.Config.Config where

import GHC.Generics (Generic)
import Data.Text (Text)

data RuntimeConfig = RuntimeConfig
  { rcLogLevel :: Text
  , rcMaxWorkers :: Int
  } deriving (Eq, Show, Generic)

defaultConfig :: RuntimeConfig
defaultConfig = RuntimeConfig { rcLogLevel = "INFO", rcMaxWorkers = 4 }
