{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

{- | AI API - REST endpoints for LLM-powered features
Phase 22-02, 22-03 of v3.0 roadmap
-}
module Surypus.API.AI (
    AIDocumentParseRequest (..),
    AIDocumentParseResponse (..),
    AIRecommendationRequest (..),
    AIRecommendationResponse (..),
    callLLM,
) where

import Control.Exception (SomeException, try)
import Data.Aeson
import Data.Aeson.Types (parseMaybe)
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import GHC.Generics (Generic)
import Network.HTTP.Simple
import System.Environment (lookupEnv)

-- | Request to parse a document
data AIDocumentParseRequest = AIDocumentParseRequest
    { aipDocContent :: Text -- Raw document text (PDF extracted)
    , aipDocType :: Text -- "invoice", "receipt", "contract", etc.
    }
    deriving (Show, Eq, Generic)

instance ToJSON AIDocumentParseRequest
instance FromJSON AIDocumentParseRequest

-- | Parsed document response
data AIDocumentParseResponse = AIDocumentParseResponse
    { aiprVendor :: Maybe Text
    , aiprInvoiceNumber :: Maybe Text
    , aiprInvoiceDate :: Maybe Text
    , aiprDueDate :: Maybe Text
    , aiprTotalAmount :: Maybe Double
    , aiprLineItems :: [Value] -- Generic line items
    , aiprRawJson :: Value -- Full extracted JSON
    }
    deriving (Show, Eq, Generic)

instance ToJSON AIDocumentParseResponse
instance FromJSON AIDocumentParseResponse

-- | Request for AI recommendations
data AIRecommendationRequest = AIRecommendationRequest
    { airQuery :: Text
    , airContext :: Value
    }
    deriving (Show, Eq, Generic)

instance ToJSON AIRecommendationRequest
instance FromJSON AIRecommendationRequest

-- | AI recommendation response
data AIRecommendationResponse = AIRecommendationResponse
    { airRecommendations :: [Text]
    , airConfidence :: Double
    }
    deriving (Show, Eq, Generic)

instance ToJSON AIRecommendationResponse
instance FromJSON AIRecommendationResponse

-- | LLM API client - calls OpenAI GPT-4
callLLM :: Text -> IO (Either Text AIDocumentParseResponse)
callLLM prompt = do
    apiKey <- lookupEnv "SURYPUS_OPENAI_API_KEY"
    case apiKey of
        Nothing -> pure $ Left "SURYPUS_OPENAI_API_KEY not set"
        Just key -> do
            let apiKeyVal = TE.encodeUtf8 (T.pack key)
                requestBody =
                    object
                        [ "model" .= ("gpt-4-turbo-preview" :: Text)
                        , "messages" .= [object ["role" .= ("user" :: Text), "content" .= prompt]]
                        , "temperature" .= (0.7 :: Double)
                        ]

            initReq <- parseRequest "https://api.openai.com/v1/chat/completions"
            let req =
                    setRequestMethod "POST" $
                        setRequestHeader "Authorization" ["Bearer " <> apiKeyVal] $
                            setRequestHeader "Content-Type" ["application/json"] $
                                setRequestBodyJSON requestBody initReq

            result <- try $ getResponseBody <$> httpLBS req :: IO (Either SomeException LBS.ByteString)

            case result of
                Left (err :: SomeException) -> pure $ Left $ "HTTP Error: " <> T.pack (show err)
                Right response -> do
                    case decode response of
                        Nothing -> pure $ Left "Parse Error: Invalid JSON response"
                        Just (obj :: Value) -> do
                            -- Extract the response text from OpenAI format
                            let textResult = extractText obj
                            -- Parse the text as our expected JSON format
                            case decode (LBS.fromStrict $ TE.encodeUtf8 textResult) of
                                Nothing -> pure $ Right $ parseTextResponse textResult
                                Just resp -> pure $ Right resp

extractText :: Value -> Text
extractText obj = case obj of
    Object o -> case parseMaybe (withObject "response" (\r -> r .: "choices")) obj of
        Just (choices :: [Value]) -> case choices of
            [Object c] -> case parseMaybe (withObject "choice" (\r -> r .: "message")) (Object c) of
                Just (msg :: Value) -> case parseMaybe (withObject "message" (\r -> r .: "content")) msg of
                    Just (txt :: Text) -> txt
                    _ -> "{}"
                _ -> "{}"
            _ -> "{}"
        _ -> "{}"
    _ -> "{}"

parseTextResponse :: Text -> AIDocumentParseResponse
parseTextResponse textResult =
    case decode (LBS.fromStrict $ TE.encodeUtf8 textResult) of
        Just (obj :: Value) ->
            case fromJSON obj of
                Success resp -> resp
                Error _ ->
                    AIDocumentParseResponse
                        { aiprVendor = Nothing
                        , aiprInvoiceNumber = Nothing
                        , aiprInvoiceDate = Nothing
                        , aiprDueDate = Nothing
                        , aiprTotalAmount = Nothing
                        , aiprLineItems = []
                        , aiprRawJson = obj
                        }
        Nothing ->
            AIDocumentParseResponse
                { aiprVendor = Nothing
                , aiprInvoiceNumber = Nothing
                , aiprInvoiceDate = Nothing
                , aiprDueDate = Nothing
                , aiprTotalAmount = Nothing
                , aiprLineItems = []
                , aiprRawJson = String textResult
                }

{- | Create a bill from parsed AI document response (stub)
In production, would map to actual Bill type and create via DAL
-}
createBillFromParse :: AIDocumentParseResponse -> Maybe Text
createBillFromParse resp =
    case (aiprVendor resp, aiprTotalAmount resp) of
        (Just vendor, Just total) -> Just $ "Bill for " <> vendor <> ": " <> T.pack (show total)
        _ -> Nothing
