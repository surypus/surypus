{-# LANGUAGE OverloadedStrings #-}

-- | Proves that the executable's application composition is the real server,
-- not a health-probe stub. No database connection is made by these cases.
module ServerWiringSpec (spec) where

import qualified Data.ByteString.Char8 as BS
import qualified DAL.Pool as Pool
import DAL.Repository.RBAC (checkUserAppPermissionRepo, mkRBACRepository)
import Network.HTTP.Types (Status, status200, status401)
import Network.Wai (Application, defaultRequest, rawPathInfo, requestMethod)
import Network.Wai.Test (request, runSession, simpleStatus)
import qualified Surypus.API.Logger as Log
import qualified Surypus.API.Server as Server
import qualified Surypus.Metrics as Metrics
import Test.Hspec

perform :: Application -> String -> IO Status
perform app path =
  simpleStatus
    <$> runSession
      (request defaultRequest {rawPathInfo = BS.pack path, requestMethod = "GET"})
      app

withApp :: (Application -> IO a) -> IO a
withApp action = do
  -- Creation is lazy: no connection is attempted until a query is run.
  pool <- Pool.createPoolWith "host=127.0.0.1 port=1 dbname=unused user=unused password=" 1
  logger <- Log.initLogger Log.Error
  metrics <- Metrics.initMetrics
  let repository = mkRBACRepository pool
      checkPerm = checkUserAppPermissionRepo repository
  app <- Server.apiServer pool logger metrics ["/api/v1/health", "/api/v1/metrics"] checkPerm
  result <- action app
  Pool.closePool pool
  pure result

spec :: Spec
spec = describe "real server wiring" $ do
  it "serves /api/v1/health without a database" $
    withApp $ \app -> perform app "/api/v1/health" `shouldReturn` status200

  it "rejects an unauthenticated protected route" $
    withApp $ \app -> perform app "/api/v1/persons" `shouldReturn` status401
