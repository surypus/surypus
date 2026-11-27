{-# LANGUAGE OverloadedStrings #-}

module AuthMiddlewareSpec (spec) where

import Data.ByteString (ByteString)
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Int (Int64)
import Data.Text (Text)
import Network.HTTP.Types (Header, Status, status200, status401, status403)
import Network.Wai (Application, Request (..), defaultRequest, responseLBS)
import Network.Wai.Test (request, runSession, simpleStatus)
import Surypus.API.AuthMiddleware (withAuthzResolverWith)
import Surypus.JWT.Token (UserClaims (..))
import Test.Hspec

okApp :: Application
okApp _ respond = respond $ responseLBS status200 [] "OK"

fakeVerify :: [Text] -> Text -> IO (Either String UserClaims)
fakeVerify roles _ = pure $ Right $ UserClaims 7 "test-user" roles Nothing

perform :: Application -> ByteString -> [Header] -> IO Status
perform app path headers =
  simpleStatus
    <$> runSession
      (request defaultRequest {rawPathInfo = path, requestMethod = "GET", requestHeaders = headers})
      app

withToken :: [Header]
withToken = [("Authorization", "Bearer fake-token")]

spec :: Spec
spec = describe "AuthMiddleware (WAI)" $ do
  it "returns 401 when no bearer token is supplied" $ do
    let app = withAuthzResolverWith [] (fakeVerify []) (\_ _ -> pure True) okApp
    perform app "/api/v1/bills" [] `shouldReturn` status401

  it "returns 403 for an unmapped route even with a valid token" $ do
    let app = withAuthzResolverWith [] (fakeVerify []) (\_ _ -> pure True) okApp
    perform app "/api/v1/unknown-resource" withToken `shouldReturn` status403

  it "does not grant access from JWT roles when the store denies" $ do
    let app = withAuthzResolverWith [] (fakeVerify ["admin"]) (\_ _ -> pure False) okApp
    perform app "/api/v1/bills" withToken `shouldReturn` status403

  it "returns 200 when the store grants the required permission" $ do
    let app = withAuthzResolverWith [] (fakeVerify []) (\_ _ -> pure True) okApp
    perform app "/api/v1/bills" withToken `shouldReturn` status200

  it "lets a public path through without a token" $ do
    let app = withAuthzResolverWith ["/api/v1/auth"] (fakeVerify []) (\_ _ -> pure False) okApp
    perform app "/api/v1/auth" [] `shouldReturn` status200

  it "does not let a public-path prefix open a protected sibling" $ do
    let app = withAuthzResolverWith ["/api/v1/auth"] (fakeVerify []) (\_ _ -> pure True) okApp
    perform app "/api/v1/authors" [] `shouldReturn` status401

  it "accepts a lower-case bearer scheme" $ do
    let app = withAuthzResolverWith [] (fakeVerify []) (\_ _ -> pure True) okApp
    perform app "/api/v1/bills" [("Authorization", "bearer fake-token")] `shouldReturn` status200

  it "passes the authenticated user id and mapped permission to the store" $ do
    calls <- newIORef []
    let check :: Int64 -> Text -> IO Bool
        check uid permission = do
          modifyIORef' calls ((uid, permission) :)
          pure True
        app = withAuthzResolverWith [] (fakeVerify []) check okApp
    status <- perform app "/api/v1/persons" withToken
    status `shouldBe` status200
    readIORef calls `shouldReturn` [(7, "read:persons")]
