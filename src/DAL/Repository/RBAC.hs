-- | RBAC Repository (Phase 1: stub)
module DAL.Repository.RBAC
  ( RBACRepository
  , mkRBACRepository
  , checkUserAppPermissionRepo
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import DAL.Database (ConnectionPool, runDb)

-- | RBAC repository handle
data RBACRepository = RBACRepository
  { repoPool :: !ConnectionPool
  }

-- | Create a new RBAC repository
mkRBACRepository :: ConnectionPool -> RBACRepository
mkRBACRepository pool = RBACRepository { repoPool = pool }

-- | Check if user has an app permission (Phase 1: always True)
checkUserAppPermissionRepo :: RBACRepository -> Int64 -> Text -> IO Bool
checkUserAppPermissionRepo _ _ _ = return True
