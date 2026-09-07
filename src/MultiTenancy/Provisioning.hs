{-# LANGUAGE OverloadedStrings #-}
module MultiTenancy.Provisioning
  ( provisionTenant
  , deactivateTenant
  , enableRLSOnAllTables
  , createRLSPoliciesForTable
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Database.Persist.Sql (SqlPersistT, rawExecute)
import Database.Persist.Postgresql (ConnectionPool)
import Control.Monad.IO.Class (liftIO)
import MultiTenancy.TenantConfig (TenantConfig(..), TenantBranding(..))

provisionTenant :: ConnectionPool -> Text -> Text -> IO (Either Text TenantConfig)
provisionTenant pool name slug = do
  let schemaName = "public"
  let config = TenantConfig
        { tcTenantId = 0
        , tcName = name
        , tcDatabaseSchema = schemaName
        , tcFeatures = mempty
        , tcBranding = TenantBranding
            { tbLogoUrl = Nothing
            , tbPrimaryColor = "#1890ff"
            , tbCompanyName = name
            }
        }
  pure $ Right config

deactivateTenant :: ConnectionPool -> Int64 -> IO (Either Text ())
deactivateTenant pool tenantId = do
  pure $ Right ()

enableRLSOnAllTables :: SqlPersistT IO ()
enableRLSOnAllTables = do
  let tables =
        [ "person", "goods", "bill", "bill_line", "stock", "location"
        , "employee", "salary", "order_head", "order_line", "payment"
        , "acc_plan", "acc_turn", "goods_price", "report_template"
        , "event_store", "audit_log", "integrations", "workflow"
        , "workflow_instance", "tech_card", "work_order", "users"
        ]
  mapM_ (\tbl -> do
    rawExecute (T.concat ["ALTER TABLE ", tbl, " ENABLE ROW LEVEL SECURITY"]) []
    rawExecute (T.concat ["DROP POLICY IF EXISTS tenant_isolation ON ", tbl]) []
    rawExecute (T.concat ["CREATE POLICY tenant_isolation ON ", tbl, " FOR ALL USING (tenant_id = app.current_tenant_id())"]) []
    ) tables

createRLSPoliciesForTable :: Text -> SqlPersistT IO ()
createRLSPoliciesForTable tableName = do
  rawExecute (T.concat ["ALTER TABLE ", tableName, " ENABLE ROW LEVEL SECURITY"]) []
  rawExecute (T.concat ["DROP POLICY IF EXISTS tenant_isolation ON ", tableName]) []
  rawExecute (T.concat ["CREATE POLICY tenant_isolation ON ", tableName, " FOR ALL USING (tenant_id = app.current_tenant_id())"]) []
