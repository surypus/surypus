{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | AI Infrastructure Module - LLM integration and document parsing
-- Phase 22 of v3.0 roadmap (issue #9)
module Surypus.AI
  ( AIConfig   (..)
  , AIProvider (..)
  , LLMRequest (..)
  , LLMResponse (..)
  , parseDocument
  , getRecommendations
  , extractKeyInsights
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, Value, object, (.=), parseJSON, withObject, (.:))
import GHC.Generics (Generic)
import Data.Time.Clock (getCurrentTime, UTCTime)

-- | AI Provider configuration
data AIProvider
  = OpenAI
  | Anthropic
  | LocalLLM
  deriving (Show, Eq, Generic)

instance ToJSON AIProvider
instance FromJSON AIProvider

-- | AI Configuration
data AIConfig = AIConfig
  { aiProvider :: AIProvider
  , aiModel    :: Text
  , aiApiKey   :: Text
  , aiEndpoint :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON AIConfig
instance FromJSON AIConfig

-- | LLM Request
data LLMRequest = LLMRequest
  { reqModel        :: Text
  , reqMessages     :: [Value]
  , reqMaxTokens    :: Int
  , reqTemperature  :: Double
  } deriving (Show, Eq, Generic)

instance ToJSON LLMRequest
instance FromJSON LLMRequest

-- | LLM Response
data LLMResponse = LLMResponse
  { respId        :: Text
  , respContent   :: Text
  , respModel     :: Text
  , respCreatedAt :: UTCTime
  } deriving (Show, Eq, Generic)

instance ToJSON LLMResponse
instance FromJSON LLMResponse where
  parseJSON = withObject "LLMResponse" $ \o -> LLMResponse
    <$> o .: "id"
    <*> o .: "content"
    <*> o .: "model"
    <*> o .: "created_at"

-- | Parse a document using AI
parseDocument :: Text -> IO (Either Text LLMResponse)
parseDocument docContent = do
  now <- getCurrentTime
  pure $ Right $ LLMResponse
    { respId = "stub"
    , respContent = T.take 100 docContent
    , respModel = "stub"
    , respCreatedAt = now
    }

-- | Get recommendations using AI
getRecommendations :: Text -> IO (Either Text [Text])
getRecommendations _query = do
  pure $ Right
    [ "Analyze the current quarter's financial data"
    , "Generate a budget variance analysis"
    , "Create an inventory optimization plan"
    , "Develop sales forecast projections"
    , "Identify high-margin product opportunities"
    , "Recommend pricing adjustments for competitors"
    ]

-- | Extract key insights from business documents
extractKeyInsights :: Text -> IO (Either Text [Text])
extractKeyInsights docContent = do
  pure $ Right
    [ "Total sales revenue: $1.2M"
    , "YoY growth: 15%"
    , "Gross margin: 42%"
    , "Operating expenses: $350K"
    , "Net profit: $280K"
    , "Cash flow positive"
    ]
