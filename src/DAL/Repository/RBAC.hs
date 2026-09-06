module DAL.Repository.RBAC
  ( RBACRepository
  , mkRBACRepository
  , checkUserAppPermissionRepo
  ) where

import Data.Int (Int64)
import DAL.Database (ConnectionPool, runDb)
import DAL.Schema
  ( UserRoleEntity (..)
  , PermissionEntity (..)
  , RolePermissionEntity (..)
  , EntityField
    ( UserRoleEntityUserId
    , PermissionEntityName
    , RolePermissionEntityRoleId
    , RolePermissionEntityPermissionId
    )
  )
import Database.Persist.Sql (selectList, (==.), (<-.), entityVal, entityKey, fromSqlKey, SelectOpt)
import Surypus.RBAC (Permission, permissionToText)

data RBACRepository = RBACRepository { repoPool :: ConnectionPool }

mkRBACRepository :: ConnectionPool -> RBACRepository
mkRBACRepository = RBACRepository

checkUserAppPermissionRepo :: RBACRepository -> Int64 -> Permission -> IO Bool
checkUserAppPermissionRepo repo userId perm = do
  let pool = repoPool repo
      permName = permissionToText perm
  userRoles <- runDb pool $ selectList [UserRoleEntityUserId ==. userId] ([] :: [SelectOpt UserRoleEntity])
  let roleIds = map (userRoleEntityRoleId . entityVal) userRoles
  if null roleIds
    then pure False
    else do
      permEntities <- runDb pool $ selectList [PermissionEntityName ==. permName] ([] :: [SelectOpt PermissionEntity])
      case permEntities of
        (pe:_) -> do
          let permId = fromSqlKey (entityKey pe)
          rpEntries <- runDb pool $ selectList
            [ RolePermissionEntityRoleId <-. roleIds
            , RolePermissionEntityPermissionId ==. permId
            ] ([] :: [SelectOpt RolePermissionEntity])
          pure $ not (null rpEntries)
        [] -> pure False
