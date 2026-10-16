{-# LANGUAGE OverloadedStrings #-}

-- | A small HTTP client for calling external APIs.
--
-- The client owns a 'Manager' (a connection pool), attaches the configured API
-- key as a @Bearer@ token, and turns transport failures and non-2xx responses
-- into 'Left' values, so callers never have to catch exceptions.
module Integration.API.ExternalAPI
  ( -- * Client
    APIClient (..)
  , initAPIClient
    -- * Requests
  , apiGet
  , apiPost
  , apiPostJSON
    -- * Helpers
  , attachApiKey
  , isSuccessResponse
  , handleAPIError
  , retryRequest
  ) where

import Control.Concurrent (threadDelay)
import Control.Exception (SomeException, try)
import Data.Aeson (ToJSON, encode)
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Network.HTTP.Client (Manager, newManager)
import qualified Network.HTTP.Client as HC
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Simple
  ( Request
  , Response
  , getResponseBody
  , getResponseStatus
  , parseRequest
  , setRequestBodyLBS
  , setRequestHeader
  )
import Network.HTTP.Types.Header (hAuthorization)
import Network.HTTP.Types.Status (statusCode)

-- | An HTTP client bound to a base URL, with an optional API key.
data APIClient = APIClient
  { clientManager :: Manager
  , clientBaseUrl :: String
  , clientApiKey :: Maybe Text
  }

-- | Create a client. The 'Manager' is shared, so connections are reused.
initAPIClient :: String -> Maybe Text -> IO APIClient
initAPIClient url key = do
  manager <- newManager tlsManagerSettings
  pure (APIClient manager url key)

-- | Attach the configured API key as a @Bearer@ token, if any.
attachApiKey :: Maybe Text -> Request -> Request
attachApiKey Nothing req = req
attachApiKey (Just key) req =
  setRequestHeader hAuthorization ["Bearer " <> TE.encodeUtf8 key] req

-- | True for a 2xx response.
isSuccessResponse :: Response a -> Bool
isSuccessResponse = (< 400) . statusCode . getResponseStatus

-- | Build the request for a relative endpoint.
buildRequest :: APIClient -> String -> IO (Either String Request)
buildRequest client endpoint = do
  parsed <- try (parseRequest (clientBaseUrl client ++ endpoint))
  pure $ case parsed of
    Left err -> Left ("bad URL: " ++ show (err :: SomeException))
    Right req -> Right (attachApiKey (clientApiKey client) req)

-- | GET an endpoint, returning the response body.
apiGet :: APIClient -> String -> IO (Either String LBS.ByteString)
apiGet client endpoint = do
  req <- buildRequest client endpoint
  case req of
    Left err -> pure (Left err)
    Right r -> do
      result <- try (HC.httpLbs r (clientManager client))
      pure $ case result of
        Left err -> Left ("request failed: " ++ show (err :: SomeException))
        Right resp
          | isSuccessResponse resp -> Right (getResponseBody resp)
          | otherwise -> Left ("HTTP " ++ show (statusCode (getResponseStatus resp)))

-- | POST a raw body.
apiPost :: APIClient -> String -> LBS.ByteString -> IO (Either String LBS.ByteString)
apiPost client endpoint body = do
  req <- buildRequest client endpoint
  case req of
    Left err -> pure (Left err)
    Right r -> do
      result <- try (HC.httpLbs (setRequestBodyLBS body r) (clientManager client))
      pure $ case result of
        Left err -> Left ("request failed: " ++ show (err :: SomeException))
        Right resp
          | isSuccessResponse resp -> Right (getResponseBody resp)
          | otherwise -> Left ("HTTP " ++ show (statusCode (getResponseStatus resp)))

-- | POST a JSON-encoded value.
apiPostJSON :: ToJSON a => APIClient -> String -> a -> IO (Either String LBS.ByteString)
apiPostJSON client endpoint value =
  apiPost client endpoint (encode value)

-- | Map a transport exception to an error string.
handleAPIError :: Either SomeException a -> Either String a
handleAPIError (Left err) = Left ("HTTP error: " ++ show err)
handleAPIError (Right val) = Right val

-- | Run an action, retrying up to @maxAttempts@ times with a linear backoff.
retryRequest :: Int -> IO a -> IO (Either SomeException a)
retryRequest maxAttempts action = go maxAttempts
  where
    go 0 = try action
    go attempts = do
      result <- try action
      case result of
        Right _ -> pure result
        Left err
          | attempts <= 1 -> pure (Left err)
          | otherwise -> do
              threadDelay (100000 * fromIntegral (maxAttempts - attempts + 1))
              go (attempts - 1)
