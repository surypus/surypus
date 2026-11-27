{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Authentication and authorization middleware for Servant.
--
-- All authorisation decisions go through 'decideRequest', which fails closed.
-- Token verification is injectable via 'withAuthzResolverWith' so the WAI
-- behaviour can be exercised in tests without a signing key or database.
module Surypus.API.AuthMiddleware
  ( withAuthzResolverAdvanced
  , withAuthzResolverWith
  , withAuthzResolver
  , AuthResult (..)
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy as BL
import Data.Char (isSpace, toLower)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.HTTP.Types (status401, status403)
import Network.Wai (Application, Response, ResponseReceived, requestHeaders, rawPathInfo, requestMethod, responseLBS)
import Surypus.API.Authorization (permissionToText)
import Surypus.API.AuthorizationDecision (AuthDecision (..), decideRequest)
import Surypus.JWT.Token (UserClaims (..), verifyToken)

-- | Authentication result
data AuthResult
  = Authenticated !UserClaims
  | AuthFailed !Text
  | AuthSkipped
  deriving (Show, Eq)

-- | Extract a bearer token. The auth-scheme is case-insensitive (RFC 6750).
extractToken :: ByteString -> Maybe Text
extractToken authHeader =
  let (scheme, rest) = BS.break isSpace authHeader
   in if BS.map toLower scheme == "bearer"
        then Just $ TE.decodeUtf8 $ BS.dropWhile isSpace rest
        else Nothing

jsonError :: String -> BL.ByteString
jsonError message =
  BL.fromStrict $
    TE.encodeUtf8 $
      "{\"error\":\"" <> T.pack (concatMap escape message) <> "\"}"
  where
    escape '"' = "\\\""
    escape '\\' = "\\\\"
    escape c = [c]

unauthorized :: (Response -> IO ResponseReceived) -> String -> IO ResponseReceived
unauthorized respond message =
  respond $ responseLBS status401 [("Content-Type", "application/json")] (jsonError message)

forbidden :: (Response -> IO ResponseReceived) -> IO ResponseReceived
forbidden respond =
  respond $ responseLBS status403 [("Content-Type", "application/json")] "{\"error\":\"Forbidden\"}"

-- | Authorization middleware with an injectable token verifier.
--
-- @checkPerm@ is the sole authority for non-public routes: JWT roles are never
-- used as a fallback grant.
withAuthzResolverWith :: [Text] -> (Text -> IO (Either String UserClaims)) -> (Int64 -> Text -> IO Bool) -> Application -> Application
withAuthzResolverWith publicPaths verify checkPerm app request respond =
  let path = TE.decodeUtf8 (rawPathInfo request)
      method = TE.decodeUtf8 (requestMethod request)
      headers = requestHeaders request
   in case decideRequest publicPaths path method Nothing of
        AuthAllow -> app request respond
        _ -> case lookup "Authorization" headers of
          Nothing -> unauthorized respond "Unauthorized"
          Just authHeader -> case extractToken authHeader of
            Nothing -> unauthorized respond "Invalid token format"
            Just token -> do
              result <- verify token
              case result of
                Left err -> unauthorized respond err
                Right claims -> do
                  let userId = ucUserId claims
                  case decideRequest publicPaths path method (Just userId) of
                    AuthAllow -> app request respond
                    AuthRequireToken -> unauthorized respond "Unauthorized"
                    AuthForbidden ->
                      -- Fail closed: no permission mapping for this route.
                      forbidden respond
                    AuthCheckPermission permission -> do
                      hasPerm <- checkPerm userId (permissionToText permission)
                      if hasPerm
                        then app request respond
                        else forbidden respond

-- | Apply RBAC authorization middleware using the real JWT verifier.
withAuthzResolverAdvanced :: [Text] -> (Int64 -> Text -> IO Bool) -> Application -> Application
withAuthzResolverAdvanced publicPaths checkPerm =
  withAuthzResolverWith publicPaths verifyToken checkPerm

-- | Middleware with a permission store that denies every protected request.
-- Retained for callers that have no persistent store configured; it must not
-- be read as an allow-all fallback.
withAuthzResolver :: [Text] -> Application -> Application
withAuthzResolver publicPaths app = withAuthzResolverAdvanced publicPaths (\_ _ -> return False) app
