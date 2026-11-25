{-# LANGUAGE OverloadedStrings #-}
-- | Negative tenant-isolation checks against a verified JWT claim.
-- The token fixtures are independently signed HS256 tokens; no stub helpers
-- are used, and the module under test is the production middleware.
module TenantIsolationSpec (spec) where

import Control.Exception (bracket)
import Data.Either (isLeft)
import qualified Data.Text as T
import System.Environment (setEnv, unsetEnv)
import Test.Hspec

import MultiTenancy.Isolation (TenantContext (..))
import MultiTenancy.Middleware (resolveTenantFromJWT)

secret :: String
secret = "test-secret-key-that-is-long-enough-for-hs256"

tenantToken, noTenantToken, invalidToken :: String
tenantToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsIm5hbWUiOiJ0ZXN0IiwidGVuYW50X2lkIjo3LCJhdWQiOiJzdXJ5cHVzLWFwaSIsImlhdCI6MTc5NTU2OTA5NSwiZXhwIjoyMTEwOTI5MDk1fQ.msWmq43rC36ShkJtIpS5Y9OGpTW7aZ1pLeAehmtns_Q"
noTenantToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsIm5hbWUiOiJ0ZXN0IiwiYXVkIjoic3VyeXB1cy1hcGkiLCJpYXQiOjE3OTU1NjkwOTUsImV4cCI6MjExMDkyOTA5NX0.zPzoY9phvPhYMuK0dX32larYSjWfzAgz8twbdK0V1b8"
invalidToken = "not-a-jwt"

withSecret :: IO a -> IO a
withSecret = bracket (setEnv "SURYPUS_JWT_SECRET" secret)
                     (const (unsetEnv "SURYPUS_JWT_SECRET"))

spec :: Spec
spec = describe "tenant isolation (verified JWT claim only)" $ do
  it "derives tenant and user ids from a signed tenant_id claim" $ withSecret $ do
    result <- resolveTenantFromJWT (T.pack tenantToken)
    case result of
      Right ctx -> do
        tcTenantId ctx `shouldBe` 7
        tcUserId ctx `shouldBe` 42
      Left err -> fail ("unexpected rejection: " ++ show err)

  it "rejects a valid token without tenant_id" $ withSecret $ do
    result <- resolveTenantFromJWT (T.pack noTenantToken)
    isLeft result `shouldBe` True

  it "rejects an invalid token" $ withSecret $ do
    result <- resolveTenantFromJWT (T.pack invalidToken)
    isLeft result `shouldBe` True

