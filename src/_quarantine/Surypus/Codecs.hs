{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

module Surypus.Codecs where

import Data.Aeson (FromJSON, ToJSON)
import GHC.Generics (Generic)

-- Simple wrapper to derive JSON instances for generic types
newtype Json a = Json {unJson :: a}
  deriving (Show, Eq, Generic)

instance (ToJSON a) => ToJSON (Json a)

instance (FromJSON a) => FromJSON (Json a)
