{-# LANGUAGE OverloadedStrings #-}

-- | RBAC repository: database-backed permission checks.
--
-- The previous implementation returned 'True' unconditionally. That made
-- every protected route effectively public as soon as the server was wired
-- to it. Checks are now parameterised, validated and fail closed.
module DAL.Repository.RBAC
  ( RBACRepository
  , mkRBACRepository
  , checkUserAppPermissionRepo
  , splitPermission
  , permissionSql
  , checkPermissionWith
  )
where

import Control.Exception (SomeException, try)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import DAL.Database (ConnectionPool, runDb)
import Database.Persist.Sql (PersistValue (..), Single (..), rawSql)

-- | RBAC repository handle
data RBACRepository = RBACRepository
  { repoPool :: !ConnectionPool
  }

-- | Create a new RBAC repository
mkRBACRepository :: ConnectionPool -> RBACRepository
mkRBACRepository pool = RBACRepository {repoPool = pool}

-- | Split @action:resource@ into validated parts.
--
-- Wildcards and malformed strings are rejected rather than interpreted as
-- "allow". @create@ is an alias for the seeded @write@ action: the API maps
-- POST to Create while the canonical permission seeds use write:*.
splitPermission :: Text -> Maybe (Text, Text)
splitPermission permission =
  case T.splitOn ":" permission of
    [action, resource]
      | not (T.null action)
          && not (T.null resource)
          && not (T.any (== '*') action)
          && not (T.any (== '*') resource) ->
          Just (if action == "create" then "write" else action, resource)
    _ -> Nothing

-- | Parameterised query. Both values are bound parameters, never interpolated.
permissionSql :: Text
permissionSql =
  "SELECT EXISTS ( \
  \  SELECT 1 FROM user_role ur \
  \  JOIN role r ON r.id = ur.role_id \
  \  LEFT JOIN role_permission rp ON rp.role_id = r.id \
  \  LEFT JOIN permission p ON p.id = rp.permission_id \
  \  WHERE ur.user_id = ? AND (p.name = ? OR r.name = 'admin') \
  \)"

-- | A query runner, injectable so the decision logic is testable without a DB.
type PermissionQuery = Text -> [PersistValue] -> IO [Single Bool]

-- | Evaluate a permission check against an injected query runner.
--
-- Any error, empty result or malformed permission is a denial.
checkPermissionWith :: PermissionQuery -> Int64 -> Text -> IO Bool
checkPermissionWith runQuery userId permission =
  case splitPermission permission of
    Nothing -> pure False
    Just (action, resource) -> do
      let expected = action <> ":" <> resource
      result <-
        try (runQuery permissionSql [PersistInt64 userId, PersistText expected]) ::
          IO (Either SomeException [Single Bool])
      pure $ case result of
        Right (Single granted : _) -> granted
        _ -> False

-- | Check if a user has an app permission against PostgreSQL.
checkUserAppPermissionRepo :: RBACRepository -> Int64 -> Text -> IO Bool
checkUserAppPermissionRepo repo userId permission =
  checkPermissionWith
    (\query params -> runDb (repoPool repo) (rawSql query params))
    userId
    permission
