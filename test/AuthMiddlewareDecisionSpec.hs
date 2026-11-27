{-# LANGUAGE OverloadedStrings #-}

module AuthMiddlewareDecisionSpec (spec) where

import Test.Hspec
import Surypus.API.Authorization (Permission (..), Resource (..))
import Surypus.API.AuthorizationDecision

spec :: Spec
spec = describe "AuthorizationDecision (fail-closed)" $ do
  it "denies an authenticated request for a route with no permission mapping" $
    decideRequest [] "/api/v1/unknown-resource" "GET" (Just 7)
      `shouldBe` AuthForbidden

  it "requires a token for an unmapped route when unauthenticated" $
    decideRequest [] "/api/v1/unknown-resource" "GET" Nothing
      `shouldBe` AuthRequireToken

  it "requires a store lookup for a mapped route" $
    decideRequest [] "/api/v1/bills" "POST" (Just 7)
      `shouldBe` AuthCheckPermission (Create Bills)

  it "maps methods to the expected permission" $ do
    decideRequest [] "/api/v1/persons" "GET" (Just 1) `shouldBe` AuthCheckPermission (Read Persons)
    decideRequest [] "/api/v1/persons" "DELETE" (Just 1) `shouldBe` AuthCheckPermission (Delete Persons)

  it "allows a public path without a token" $
    decideRequest ["/api/v1/auth/login"] "/api/v1/auth/login" "POST" Nothing
      `shouldBe` AuthAllow

  it "does not treat a path prefix as a public-path match" $
    decideRequest ["/api/v1/auth"] "/api/v1/authors" "GET" Nothing
      `shouldBe` AuthRequireToken

  it "allows sub-paths of a public directory" $
    isPublicPath ["/api/v1/docs/"] "/api/v1/docs/guide/intro"
      `shouldBe` True

  it "does not allow a sibling that merely shares the prefix" $
    isPublicPath ["/api/v1/auth"] "/api/v1/authors/delete"
      `shouldBe` False
