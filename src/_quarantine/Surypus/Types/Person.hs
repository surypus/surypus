{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Surypus.Types.Person
  ( Person (..),
    PersonType (..),
    PersonStatus (..),
    PersonInput (..),
    PersonSummary (..),
  )
where

import Data.Aeson (FromJSON (..), Options (..), ToJSON (..), defaultOptions, genericParseJSON, genericToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import Surypus.Types.Common (camelTo2)

data Person = Person
  { personId :: !Int64,
    personName :: !Text,
    personINN :: !Text,
    personKPP :: !(Maybe Text),
    personType :: !PersonType,
    personStatus :: !PersonStatus,
    personCreatedAt :: !UTCTime,
    personUpdatedAt :: !(Maybe UTCTime)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Person where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 6}

instance FromJSON Person where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 6}

data PersonType = Customer | Supplier | Employee | Partner
  deriving stock (Show, Eq, Generic)

instance ToJSON PersonType

instance FromJSON PersonType

data PersonStatus = PersonActive | PersonBlocked | PersonDeleted
  deriving stock (Show, Eq, Generic)

instance ToJSON PersonStatus

instance FromJSON PersonStatus

data PersonInput = PersonInput
  { piName :: !Text,
    piINN :: !Text,
    piKPP :: !(Maybe Text),
    piPersonType :: !PersonType,
    piStatus :: !PersonStatus
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON PersonInput where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = drop 2}

instance FromJSON PersonInput where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = drop 2}

data PersonSummary = PersonSummary
  { psId :: !Int64,
    psName :: !Text,
    psType :: !PersonType,
    psStatus :: !PersonStatus
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON PersonSummary where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = drop 2}

instance FromJSON PersonSummary where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = drop 2}
