{-# LANGUAGE OverloadedStrings #-}

-- | Pure authorization decisions for the WAI authentication middleware.
--
-- Keeping the decision function pure (and free of JWT/WAI dependencies) makes
-- the security-critical branch structure directly testable and prevents the
-- middleware from silently failing open when a route has no permission map.
module Surypus.API.AuthorizationDecision
  ( AuthDecision (..),
    decideRequest,
    isPublicPath,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Surypus.API.Authorization (Permission, requiredPermissionForPathMethod)

-- | The decision for a request before any permission-store lookup is done.
--
-- 'AuthCheckPermission' is the only branch that may allow a non-public
-- request, and it requires an explicit, injected store lookup.
data AuthDecision
  = AuthAllow
  | AuthRequireToken
  | AuthForbidden
  | AuthCheckPermission !Permission
  deriving (Show, Eq)

-- | Public path matching on segment boundaries.
--
-- A raw @isPrefixOf@ check lets @/api/v1/auth@ authorise
-- @/api/v1/authors/delete@; matching must stop at a path separator.
isPublicPath :: [Text] -> Text -> Bool
isPublicPath publicPaths path = any (`matches` path) publicPaths
  where
    matches :: Text -> Text -> Bool
    matches publicPath actual
      | publicPath == actual = True
      | "/" `T.isSuffixOf` publicPath = publicPath `T.isPrefixOf` actual
      | otherwise = (publicPath <> "/") `T.isPrefixOf` actual

-- | Decide what must happen for a request.
--
-- /Fail closed/: an authenticated request for a route that has no permission
-- mapping is denied. The presence of a user id is checked but never used to
-- grant access on its own.
decideRequest :: [Text] -> Text -> Text -> Maybe Int64 -> AuthDecision
decideRequest publicPaths path method mUserId
  | isPublicPath publicPaths path = AuthAllow
  | Nothing <- mUserId = AuthRequireToken
  | Just _ <- mUserId =
      case requiredPermissionForPathMethod path method of
        Nothing -> AuthForbidden
        Just permission -> AuthCheckPermission permission
