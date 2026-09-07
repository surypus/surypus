{-# LANGUAGE OverloadedStrings #-}
-- | Surypus AI OpenAI (Phase 1: stub)
module Surypus.AI.OpenAI
  ( callOpenAI
  , OpenAIConfig(..)
  , defaultOpenAIConfig
  ) where

import Data.Text (Text)

-- | OpenAI configuration
data OpenAIConfig = OpenAIConfig
  { apiKey :: !Text
  , model :: !Text
  , baseURL :: !Text
  } deriving (Show)

-- | Default OpenAI configuration
defaultOpenAIConfig :: OpenAIConfig
defaultOpenAIConfig = OpenAIConfig
  { apiKey = ""
  , model = "gpt-4"
  , baseURL = "https://api.openai.com"
  }

-- | Call OpenAI API (stub)
callOpenAI :: OpenAIConfig -> Text -> IO (Either Text Text)
callOpenAI _ _ = return $ Right "stub-response"
