{-# LANGUAGE OverloadedStrings #-}
-- | Surypus AI Anthropic (Phase 1: stub)
module Surypus.AI.Anthropic
  ( callAnthropic
  , AnthropicConfig(..)
  , defaultAnthropicConfig
  ) where

import Data.Text (Text)

-- | Anthropic configuration
data AnthropicConfig = AnthropicConfig
  { apiKey :: !Text
  , model :: !Text
  , baseURL :: !Text
  } deriving (Show)

-- | Default Anthropic configuration
defaultAnthropicConfig :: AnthropicConfig
defaultAnthropicConfig = AnthropicConfig
  { apiKey = ""
  , model = "claude-3-sonnet"
  , baseURL = "https://api.anthropic.com"
  }

-- | Call Anthropic API (stub)
callAnthropic :: AnthropicConfig -> Text -> IO (Either Text Text)
callAnthropic _ _ = return $ Right "stub-response"
