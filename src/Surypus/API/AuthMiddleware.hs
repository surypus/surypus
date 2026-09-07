{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Authentication and authorization middleware for Servant
module Surypus.API.AuthMiddleware
  ( withAuthzResolverAdvanced,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.HTTP.Types (status401, status403)
import Network.Wai (Application, requestHeaders, rawPathInfo, requestMethod, responseLBS)
import Surypus.API.Authorization (requiredPermissionForPathMethod)
import Surypus.JWT.Token (UserClaims(..), verifyToken)

-- | Apply RBAC authorization middleware.
-- Skips auth for public paths; otherwise verifies JWT and checks permission.
-- The checkPermission function should be wired with a real RBAC store.
withAuthzResolverAdvanced ::
  -- | Public paths (no auth required)
  [Text] ->
  -- | Permission checker: userId -> requiredPermission -> IO Bool
  (Int64 -> Text -> IO Bool) ->
  -- | Inner application
  Application ->
  -- | Secured application
  Application
withAuthzResolverAdvanced publicPaths checkPermission app req respond = do
  let path = TE.decodeUtf8 (rawPathInfo req)
      authHeader = lookup "Authorization" (requestHeaders req)
  if path `elem` publicPaths
    then app req respond
    else case authHeader of
      Nothing ->
        respond $ responseLBS status401 [("Content-Type", "text/plain")] "Unauthorized: missing Authorization header"
      Just hdr -> do
        let hdrStr = TE.decodeUtf8 hdr
        case T.stripPrefix "Bearer " hdrStr of
          Nothing ->
            respond $ responseLBS status401 [("Content-Type", "text/plain")] "Unauthorized: invalid Authorization header format"
          Just token ->
            verifyToken token >>= \case
              Left _ ->
                respond $ responseLBS status401 [("Content-Type", "text/plain")] "Unauthorized: invalid or expired token"
              Right claims -> do
                let mPerm = requiredPermissionForPathMethod (requestMethod req) path
                case mPerm of
                  Nothing -> app req respond
                  Just perm -> do
                    allowed <- checkPermission (ucUserId claims) perm
                    if allowed
                      then app req respond
                      else respond $ responseLBS status403 [("Content-Type", "text/plain")] "Forbidden: insufficient permissions"
