{-# LANGUAGE OverloadedStrings #-}

-- | Health contract: real pool probe, constant JSON, no driver/DSN leakage.
module API.HealthSpec (spec) where

import Control.Monad.Logger (runNoLoggingT)
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BLC
import qualified DAL.Pool as Pool
import Surypus.API.Server (healthEndpoint)
import Database.Persist.Postgresql (createPostgresqlPool)
import Network.HTTP.Types (status200, status503)
import Network.Wai (Application, defaultRequest, rawPathInfo, requestMethod, responseLBS)
import Network.Wai.Test (SResponse (..), request, runSession, simpleStatus)
import System.Environment (lookupEnv)
import Test.Hspec

dummy :: Application
dummy _ respond = respond $ responseLBS status503 [] "unused"

get :: Application -> String -> IO SResponse
get app path =
  runSession
    (request defaultRequest {rawPathInfo = BC.pack path, requestMethod = "GET"})
    app

assertSafeBody :: BL.ByteString -> Expectation
assertSafeBody body =
  mapM_
    (\bad -> BC.isInfixOf (BC.pack bad) (BL.toStrict body) `shouldBe` False)
    ["postgres", "DATABASE_URL", "password", "Exception"]

spec :: Spec
spec = describe "health endpoint" $ do
  it "reports 503 with a constant JSON body when the pool is dead" $ do
    pool <- runNoLoggingT (createPostgresqlPool (BC.pack "host=127.0.0.1 port=1 dbname=x user=x password=x") 1)
    let app = healthEndpoint pool dummy
    a <- get app "/api/v1/health"
    b <- get app "/api/v1/health/db"
    simpleStatus a `shouldBe` status503
    simpleStatus b `shouldBe` status503
    simpleBody a `shouldBe` simpleBody b
    simpleBody a `shouldBe` "{\"status\":\"error\",\"db\":\"down\"}"
    assertSafeBody (simpleBody a)
    Pool.closePool pool

  it "reports 200 with a constant JSON body for a live pool" $ do
    mUrl <- lookupEnv "SURYPUS_TEST_DATABASE_URL"
    case mUrl of
      Nothing -> pendingWith "set SURYPUS_TEST_DATABASE_URL for the live health probe"
      Just url -> do
        pool <- runNoLoggingT (createPostgresqlPool (BC.pack url) 2)
        let app = healthEndpoint pool dummy
        a <- get app "/api/v1/health"
        b <- get app "/api/v1/health/db"
        simpleStatus a `shouldBe` status200
        simpleStatus b `shouldBe` status200
        simpleBody a `shouldBe` simpleBody b
        simpleBody a `shouldBe` "{\"status\":\"ok\",\"db\":\"ok\"}"
        assertSafeBody (simpleBody a)
        Pool.closePool pool
