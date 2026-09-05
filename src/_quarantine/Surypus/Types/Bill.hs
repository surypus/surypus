{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Surypus.Types.Bill
  ( Bill (..),
    BillStatus (..),
    BillLine (..),
    BillInput (..),
    BillSummary (..),
  )
where

import Data.Aeson (FromJSON (..), Options (..), ToJSON (..), defaultOptions, genericParseJSON, genericToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import Surypus.Types.Common (camelTo2)

data Bill = Bill
  { billId :: !Int64,
    billNumber :: !Text,
    billStatus :: !BillStatus,
    billAmount :: !Double,
    billLines :: ![BillLine],
    billCreatedAt :: !UTCTime,
    billUpdatedAt :: !(Maybe UTCTime),
    billPersonId :: !(Maybe Int64),
    billLocationId :: !(Maybe Int64)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Bill where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

instance FromJSON Bill where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

data BillStatus
  = Draft
  | Posted
  | Cancelled
  | Archived
  deriving stock (Show, Eq, Generic, Enum, Bounded)

instance ToJSON BillStatus

instance FromJSON BillStatus

data BillLine = BillLine
  { lineId :: !Int64,
    lineBillId :: !Int64,
    lineGoodId :: !Int64,
    lineQuantity :: !Int,
    linePrice :: !Double,
    lineTotal :: !Double,
    lineTaxRate :: !(Maybe Double)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON BillLine where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

instance FromJSON BillLine where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

data BillInput = BillInput
  { inputNumber :: !Text,
    inputAmount :: !Double,
    inputStatus :: !(Maybe BillStatus),
    inputLines :: ![BillLineInput],
    inputPersonId :: !(Maybe Int64),
    inputLocationId :: !(Maybe Int64)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON BillInput where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

instance FromJSON BillInput where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

data BillLineInput = BillLineInput
  { lineInputGoodId :: !Int64,
    lineInputQuantity :: !Int,
    lineInputPrice :: !Double,
    lineInputTaxRate :: !(Maybe Double)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON BillLineInput where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 9}

instance FromJSON BillLineInput where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 9}

data BillSummary = BillSummary
  { summaryId :: !Int64,
    summaryNumber :: !Text,
    summaryStatus :: !BillStatus,
    summaryTotal :: !Double,
    summaryItemCount :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON BillSummary where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 7}

instance FromJSON BillSummary where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 7}

-- Remove duplicate helper functions and use Data.Char
