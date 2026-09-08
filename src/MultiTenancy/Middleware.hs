{-# LANGUAGE OverloadedStrings #-}
module MultiTenancy.Middleware
  ( tenantMiddleware
  , resolveTenantFromJWT
  , TenantResolution(..)
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.HTTP.Types (status401)
import Control.Exception (bracket_)
import Network.Wai (Application, requestHeaders, responseLBS, rawPathInfo)
import qualified Network.Wai as W
import qualified Surypus.JWT.Token as JWT
import MultiTenancy.Isolation (TenantContext(..))
import DAL.Database (setCurrentTenantContext, clearCurrentTenantContext)

data TenantResolution
  = TenantFromJWT
  | TenantFromHeader
  deriving (Eq, Show)

resolveTenantFromJWT :: Text -> IO (Either Text TenantContext)
resolveTenantFromJWT tokenStr = do
  result <- JWT.verifyToken tokenStr
  case result of
    Left err -> pure $ Left (T.pack err)
    Right claims -> case JWT.ucTenantId claims of
      Just tid -> pure $ Right TenantContext
        { tcTenantId = tid
        , tcSchemaName = "public"
        , tcUserId = JWT.ucUserId claims
        }
      Nothing -> pure $ Left "JWT token missing tenant_id claim"

tenantMiddleware :: Application -> Application
tenantMiddleware app req respond = do
  let path = W.rawPathInfo req
  if path == "/api/v1/login"
    then app req respond
    else case lookup "Authorization" (W.requestHeaders req) of
      Nothing -> app req respond
      Just hdr -> do
        let hdrStr = TE.decodeUtf8 hdr
        case T.stripPrefix "Bearer " hdrStr of
          Nothing -> app req respond
          Just token -> do
            result <- resolveTenantFromJWT token
            case result of
              Left _ -> app req respond
              Right ctx ->
                bracket_
                  (setCurrentTenantContext (tcTenantId ctx) (tcUserId ctx))
                  clearCurrentTenantContext
                  (app req respond)
