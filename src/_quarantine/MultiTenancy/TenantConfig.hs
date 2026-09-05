{-# LANGUAGE OverloadedStrings #-}
module MultiTenancy.TenantConfig
  ( TenantConfig(..)
  , TenantBranding(..)
  , loadTenantConfig
  , tenantSchema
  , defaultTenant
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Database.Persist.Postgresql (ConnectionPool)

data TenantConfig = TenantConfig
  { tcTenantId :: !Int64
  , tcName :: !Text
  , tcDatabaseSchema :: !Text
  , tcFeatures :: !(Map Text Bool)
  , tcBranding :: !TenantBranding
  } deriving (Eq, Show)

data TenantBranding = TenantBranding
  { tbLogoUrl :: !(Maybe Text)
  , tbPrimaryColor :: !Text
  , tbCompanyName :: !Text
  } deriving (Eq, Show)

defaultTenant :: TenantConfig
defaultTenant = TenantConfig
  { tcTenantId = 0
  , tcName = "Default Tenant"
  , tcDatabaseSchema = "public"
  , tcFeatures = Map.empty
  , tcBranding = TenantBranding
      { tbLogoUrl = Nothing
      , tbPrimaryColor = "#1890ff"
      , tbCompanyName = "Default Tenant"
      }
  }

loadTenantConfig :: ConnectionPool -> Int64 -> IO (Maybe TenantConfig)
loadTenantConfig pool tenantId = do
  -- TODO: Implement DB-backed tenant config lookup
  -- Future implementation will query tenant_config table for given tenant_id
  -- Should return TenantConfig with features and branding settings
  -- For now, return default tenant for testing
  
  if tenantId == 0
    then pure $ Just defaultTenant
    else pure Nothing

tenantSchema :: TenantConfig -> Text
tenantSchema = tcDatabaseSchema

-- | Get all tenant IDs for current connection
getTenantIds :: ConnectionPool -> IO [Int64]
getTenantIds pool = do
  -- TODO: Query tenant_config table to get all tenant IDs
  -- This is needed for tenant switching functionality
  pure [0]  -- Default tenant for now

-- | Update tenant configuration
updateTenantConfig :: ConnectionPool -> TenantConfig -> IO Bool
updateTenantConfig pool config = do
  -- TODO: Implement update functionality
  -- Will update tenant_config table with new settings
  pure True  -- Assume success for now
