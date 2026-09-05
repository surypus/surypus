{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.AI.OpenAI (
    callOpenAI,
    OpenAIConfig (..),
    defaultOpenAIConfig,
) where

import Control.Exception (try, SomeException)
import Data.Aeson
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.HTTP.Simple
import System.Environment (lookupEnv)

data OpenAIConfig = OpenAIConfig
    { apiKey :: Text
    , model :: Text
    , baseURL :: Text
    }
    deriving (Show)

defaultOpenAIConfig :: IO OpenAIConfig
defaultOpenAIConfig = do
    key <- lookupEnv "SURYPUS_OPENAI_API_KEY"
    pure $
        OpenAIConfig
            { apiKey = maybe "" T.pack key
            , model = "gpt-4-turbo-preview"
            , baseURL = "https://api.openai.com/v1/chat/completions"
            }

data OpenAIRequest = OpenAIRequest
    { model_req :: Text
    , messages :: [Message]
    , temperature :: Double
    }
    deriving (Show)

data Message = Message
    { role :: Text
    , content :: Text
    }
    deriving (Show)

instance ToJSON OpenAIRequest where
    toJSON req =
        object
            [ "model" .= model_req req
            , "messages" .= messages req
            , "temperature" .= temperature req
            ]

instance ToJSON Message where
    toJSON msg =
        object
            [ "role" .= role msg
            , "content" .= content msg
            ]

instance FromJSON Message where
    parseJSON = withObject "Message" $ \o ->
        Message
            <$> o .: "role"
            <*> o .: "content"

instance FromJSON OpenAIRequest where
    parseJSON = withObject "OpenAIRequest" $ \o ->
        OpenAIRequest
            <$> o .: "model"
            <*> o .: "messages"
            <*> o .: "temperature"

data OpenAIResponse = OpenAIResponse
    { choices :: [Choice]
    }
    deriving (Show)

data Choice = Choice
    { message :: Message
    }
    deriving (Show)

instance FromJSON OpenAIResponse where
    parseJSON = withObject "OpenAIResponse" $ \o ->
        OpenAIResponse
            <$> o .: "choices"

instance FromJSON Choice where
    parseJSON = withObject "Choice" $ \o ->
        Choice
            <$> o .: "message"

data AIError = AIError
    { errorCode :: Text
    , errorMessage :: Text
    }
    deriving (Show)

instance FromJSON AIError where
    parseJSON = withObject "AIError" $ \o ->
        AIError
            <$> o .: "code"
            <*> o .: "message"

callOpenAI :: Text -> IO (Either Text Text)
callOpenAI prompt = do
    config <- defaultOpenAIConfig
    let apiKeyVal = TE.encodeUtf8 (apiKey config)
        requestBody =
            OpenAIRequest
                { model_req = model config
                , messages = [Message "user" prompt]
                , temperature = 0.7
                }

    initReq <- parseRequest (T.unpack (baseURL config))
    let req =
            setRequestMethod "POST" $
                setRequestHeader "Authorization" ["Bearer " <> apiKeyVal] $
                    setRequestHeader "Content-Type" ["application/json"] $
                        setRequestBodyJSON requestBody initReq

    result <- try $ getResponseBody <$> httpLBS req :: IO (Either SomeException LBS.ByteString)

    case result of
        Left (err :: SomeException) -> pure $ Left $ "HTTP Error: " <> T.pack (show err)
        Right response -> case eitherDecode response of
            Left err -> pure $ Left $ "Parse Error: " <> T.pack err
            Right (OpenAIResponse chs) -> case chs of
                (Choice msg) : _ -> pure $ Right (TE.decodeUtf8 $ LBS.toStrict $ encode $ content msg)
                _ -> pure $ Left "No response from OpenAI"
