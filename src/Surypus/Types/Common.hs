{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Surypus.Types.Common
  ( ApiError (..),
    ApiResponse (..),
    Pagination (..),
    SortOrder (..),
    QueryParams (..),
    Money (..),
    Percentage (..),
    TimestampRange (..),
    camelTo2,
  )
where

import Data.Aeson (FromJSON (..), Options (..), ToJSON (..), Value (String), defaultOptions, genericParseJSON, genericToJSON, parseJSON)
import Data.Char (isUpper, toLower)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)

-- | API Error response
data ApiError = ApiError
  { errCode :: !Text,
    errMessage :: !Text,
    errDetails :: !(Maybe Value),
    errTimestamp :: !UTCTime
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON ApiError where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

instance FromJSON ApiError where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

-- | Generic API Response wrapper
data ApiResponse a = ApiResponse
  { respData :: !a,
    respMeta :: !(Maybe ResponseMeta)
  }
  deriving stock (Show, Eq, Generic)

instance (ToJSON a) => ToJSON (ApiResponse a) where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

instance (FromJSON a) => FromJSON (ApiResponse a) where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

-- | Response metadata
data ResponseMeta = ResponseMeta
  { metaPage :: !(Maybe Int),
    metaPageSize :: !(Maybe Int),
    metaTotal :: !(Maybe Int64),
    metaTotalPages :: !(Maybe Int)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON ResponseMeta where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

instance FromJSON ResponseMeta where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

-- | Pagination parameters
data Pagination = Pagination
  { page :: !Int,
    pageSize :: !Int
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)

defaultPagination :: Pagination
defaultPagination = Pagination {page = 1, pageSize = 50}

-- | Sort order
data SortOrder = Ascending | Descending
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)

-- | Query parameters for list endpoints
data QueryParams = QueryParams
  { qpSearch :: !(Maybe Text),
    qpFilter :: !(Maybe Text),
    qpSortBy :: !(Maybe Text),
    qpSortOrder :: !(Maybe SortOrder),
    qpPage :: !(Maybe Int),
    qpPageSize :: !(Maybe Int)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON QueryParams where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 2}

instance FromJSON QueryParams where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 2}

-- | Money type (fixed precision)
newtype Money = Money {unMoney :: Double}
  deriving stock (Show, Eq, Generic)

instance ToJSON Money where
  toJSON (Money v) = toJSON v

instance FromJSON Money where
  parseJSON v = Money <$> parseJSON v

-- | Percentage type (0-100)
newtype Percentage = Percentage {unPercentage :: Double}
  deriving stock (Show, Eq, Generic)

instance ToJSON Percentage where
  toJSON (Percentage v) = toJSON v

instance FromJSON Percentage where
  parseJSON v = Percentage <$> parseJSON v

-- | Timestamp range for queries
data TimestampRange = TimestampRange
  { rangeFrom :: !UTCTime,
    rangeTo :: !UTCTime
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON TimestampRange where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

instance FromJSON TimestampRange where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

-- Helper function for field label modification
camelTo2 :: Char -> String -> String
camelTo2 _ [] = []
camelTo2 c (x : xs) = toLower x : go xs
  where
    go [] = []
    go (y : ys)
      | isUpper y = c : toLower y : go ys
      | otherwise = y : go ys
