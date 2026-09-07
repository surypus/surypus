{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Authentication and authorization middleware for Servant
module Surypus.API.AuthMiddleware
  ( withAuthzResolverAdvanced
  , withAuthzResolver
  , AuthResult(..)
  , authenticateRequest
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.HTTP.Types (status401, status403)
import Network.Wai (Application, requestHeaders, rawPathInfo, requestMethod, responseLBS)
import Surypus.API.Authorization (requiredPermissionForPathMethod, checkPermission)
import Surypus.JWT.Token (UserClaims(..), verifyToken, SecretKey, defaultSecretKey)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS

-- | Authentication result
data AuthResult
  = Authenticated !UserClaims
  | AuthFailed !Text
  | AuthSkipped
  deriving (Show, Eq)

-- | Extract JWT token from Authorization header
extractToken :: ByteString -> Maybe Text
extractToken authHeader = do
  let prefix = "Bearer "
  if prefix `BS.isPrefixOf` authHeader
    then Just $ TE.decodeUtf8 $ BS.drop (length prefix) authHeader
    else Nothing

-- | Authenticate a request
authenticateRequest :: SecretKey -> ByteString -> ByteString -> IO AuthResult
authenticateRequest secret path method = do
  let mToken = extractToken method
  case mToken of
    Nothing -> return $ AuthFailed "Missing or invalid Authorization header"
    Just token -> do
      result <- verifyToken secret token
      case result of
        Left err -> return $ AuthFailed err
        Right claims -> return $ Authenticated claims

-- | Apply RBAC authorization middleware.
-- Skips auth for public paths; otherwise verifies JWT and checks permission.
withAuthzResolverAdvanced :: [Text] -> (Int64 -> Text -> IO Bool) -> Application -> Application
withAuthzResolverAdvanced publicPaths checkPerm app request respond = do
  let path = TE.decodeUtf8 (rawPathInfo request)
      method = TE.decodeUtf8 (requestMethod request)
      headers = requestHeaders request

  -- Check if path is public
  if any (`T.isPrefixOf` path) publicPaths
    then app request respond
    else do
      -- Find Authorization header
      let mAuthHeader = lookup "Authorization" headers
      case mAuthHeader of
        Nothing -> respond $ responseLBS status401 [("Content-Type", "application/json")] "{\"error\":\"Unauthorized\"}"
        Just authHeader -> do
          let mToken = extractToken authHeader
          case mToken of
            Nothing -> respond $ responseLBS status401 [("Content-Type", "application/json")] "{\"error\":\"Invalid token format\"}"
            Just token -> do
              result <- verifyToken defaultSecretKey token
              case result of
                Left err -> respond $ responseLBS status401 [("Content-Type", "application/json")] $ BS.pack $ "{\"error\":\"" ++ T.unpack err ++ "\"}"
                Right claims -> do
                  let mRequiredPerm = requiredPermissionForPathMethod path method
                  case mRequiredPerm of
                    Nothing -> app request respond
                    Just perm -> do
                      let userId = claimsUserId claims
                          userRoles = claimsRoles claims
                      hasPerm <- checkPerm userId (Surypus.API.Authorization.permissionToText perm)
                      if hasPerm || checkPermission userRoles perm
                        then app request respond
                        else respond $ responseLBS status403 [("Content-Type", "application/json")] "{\"error\":\"Forbidden\"}"

-- | Simple auth middleware with default secret key
withAuthzResolver :: [Text] -> Application -> Application
withAuthzResolver publicPaths app = withAuthzResolverAdvanced publicPaths (\_ _ -> return False) app
