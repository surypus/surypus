{-# LANGUAGE OverloadedStrings #-}

-- | QuickCheck properties for 'MultiTenancy.TenantConfig'.
-- Pure functions only (no DB/IO); targets TASK-030 multi-tenant
-- QuickCheck isolation follow-up.
module MultiTenancy.TenantConfigSpec (spec) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Test.Hspec

import MultiTenancy.TenantConfig

spec :: Spec
spec = do
  describe "MultiTenancy.TenantConfig" $ do
    describe "defaultTenant" $ do
      it "has a non-empty name" $ do
        tcName defaultTenant `shouldNotBe` ""
      it "has a non-empty database schema" $ do
        tcDatabaseSchema defaultTenant `shouldNotBe` ""
      it "has an empty features map" $ do
        tcFeatures defaultTenant `shouldBe` Map.empty
      it "has default branding values" $ do
        tbLogoUrl (tcBranding defaultTenant) `shouldBe` Nothing
        tbPrimaryColor (tcBranding defaultTenant) `shouldBe` "#1890ff"
        tbCompanyName (tcBranding defaultTenant) `shouldBe` "Default Tenant"

    describe "tenantSchema" $ do
      it "returns the database schema of defaultTenant" $ do
        tenantSchema defaultTenant `shouldBe` "public"
      it "reflects a custom database schema" $ do
        let cfg = defaultTenant { tcDatabaseSchema = "tenants_app" }
        tenantSchema cfg `shouldBe` "tenants_app"
