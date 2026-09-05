{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.AI.Anthropic (
    callAnthropic,
    AnthropicConfig (..),
    defaultAnthropicConfig,
) where

import Control.Exception (try, SomeException)
import Data.Aeson
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.HTTP.Simple
import System.Environment (lookupEnv)

data AnthropicConfig = AnthropicConfig
    { apiKey :: Text
    , model :: Text
    , baseURL :: Text
    }
    deriving (Show)

defaultAnthropicConfig :: IO AnthropicConfig
defaultAnthropicConfig = do
    key <- lookupEnv "SURYPUS_ANTHROPIC_API_KEY"
    pure $
        AnthropicConfig
            { apiKey = maybe "" T.pack key
            , model = "claude-3-opus-20240229"
            , baseURL = "https://api.anthropic.com/v1/messages"
            }

data AnthropicRequest = AnthropicRequest
    { model_req :: Text
    , max_tokens :: Int
    , messages :: [Message]
    }
    deriving (Show)

data Message = Message
    { role :: Text
    , content :: Text
    }
    deriving (Show)

instance ToJSON AnthropicRequest where
    toJSON req =
        object
            [ "model" .= model_req req
            , "max_tokens" .= max_tokens req
            , "messages" .= messages req
            ]

instance ToJSON Message where
    toJSON msg =
        object
            [ "role" .= role msg
            , "content" .= content msg
            ]

data AnthropicResponse = AnthropicResponse
    { content_resp :: [Content]
    }
    deriving (Show)

data Content = Content
    { text :: Text
    }
    deriving (Show)

instance FromJSON Content where
    parseJSON = withObject "Content" $ \o ->
        Content
            <$> o .: "text"

instance FromJSON AnthropicResponse where
    parseJSON = withObject "AnthropicResponse" $ \o ->
        AnthropicResponse
            <$> o .: "content"

callAnthropic :: Text -> IO (Either Text Text)
callAnthropic prompt = do
    config <- defaultAnthropicConfig
    let apiKeyVal = TE.encodeUtf8 (apiKey config)
        requestBody =
            AnthropicRequest
                { model_req = model config
                , max_tokens = 4096
                , messages = [Message "user" prompt]
                }

    initReq <- parseRequest (T.unpack (baseURL config))
    let req =
            setRequestMethod "POST" $
                setRequestHeader "x-api-key" [apiKeyVal] $
                    setRequestHeader "Content-Type" ["application/json"] $
                        setRequestHeader "anthropic-version" ["2023-06-01"] $
                            setRequestBodyJSON requestBody initReq

    result <- try $ getResponseBody <$> httpLBS req :: IO (Either SomeException LBS.ByteString)

    case result of
        Left (err :: SomeException) -> pure $ Left $ "HTTP Error: " <> T.pack (show err)
        Right response -> case eitherDecode response of
            Left err -> pure $ Left $ "Parse Error: " <> T.pack err
            Right (AnthropicResponse contents) -> case contents of
                (Content txt) : _ -> pure $ Right txt
                _ -> pure $ Left "No response from Anthropic"
