{-# LANGUAGE OverloadedStrings #-}
module MultiTenancy.Isolation
  ( TenantContext(..)
  , runDbWithTenant
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Sql (SqlPersistT, rawExecute, PersistValue(..))
import Database.Persist.Postgresql (ConnectionPool)
import Database.Persist.Sql (runSqlPool)

data TenantContext = TenantContext
  { tcTenantId :: !Int64
  , tcSchemaName :: !Text
  , tcUserId :: !Int64
  } deriving (Eq, Show)

-- | Run a database action scoped to a specific tenant.
runDbWithTenant :: TenantContext -> ConnectionPool -> SqlPersistT IO a -> IO a
runDbWithTenant ctx pool action = do
  runSqlPool (do
    rawExecute "SELECT set_config('app.tenant_id', ?, TRUE)"
      [PersistText (T.pack $ show $ tcTenantId ctx)]
    rawExecute "SELECT set_config('app.user_id', ?, TRUE)"
      [PersistText (T.pack $ show $ tcUserId ctx)]
    result <- action
    rawExecute "SELECT set_config('app.tenant_id', '', TRUE)" []
    rawExecute "SELECT set_config('app.user_id', '', TRUE)" []
    pure result
    ) pool

