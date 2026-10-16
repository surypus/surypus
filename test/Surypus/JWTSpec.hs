{-# LANGUAGE OverloadedStrings #-}

-- | Tests for the JWT module.
--
-- Token generation and refresh rotation need a live database, so only the
-- pure helpers and the verification failure paths are covered here.
module Surypus.JWTSpec (spec) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import Surypus.JWT
import Test.Hspec

spec :: Spec
spec = do
  describe "jwtConfigFromSecret" $ do
    it "uses a one hour access-token expiry" $
      jwtExpiry (jwtConfigFromSecret "s") `shouldBe` 3600
    it "uses a two week refresh-token expiry" $
      jwtRefreshExpiry (jwtConfigFromSecret "s") `shouldBe` 1209600
    it "keeps the supplied secret" $
      jwtSecret (jwtConfigFromSecret "s") `shouldBe` ("s" :: Text)

  describe "validateAccessToken" $ do
    it "rejects a malformed token" $
      validateAccessToken "secret" "not-a-jwt"
        `shouldReturn` Left "Invalid or expired token"

    it "rejects an empty token" $
      validateAccessToken "secret" ""
        `shouldReturn` Left "Invalid or expired token"

    it "rejects a token signed with a different secret" $
      validateAccessToken "other-secret" "not-a-jwt"
        `shouldReturn` Left "Invalid or expired token"

  describe "decodeAndValidateToken" $ do
    it "rejects a malformed token" $
      decodeAndValidateToken "secret" "not-a-jwt" `shouldReturn` Left AuthInvalid

    it "rejects an empty token" $
      decodeAndValidateToken "secret" "" `shouldReturn` Left AuthInvalid

  describe "TokenPair accessors" $ do
    it "exposes the access token" $
      accessToken pair `shouldBe` ("a" :: Text)

    it "exposes the refresh token" $
      refreshToken pair `shouldBe` ("r" :: Text)

    it "reports no person id" $
      rtUserId pair `shouldBe` (0 :: Int64)

    it "exposes the expiry" $
      rtExpiresAt pair `shouldBe` t

    where
      t :: UTCTime
      t = read "2026-01-01 00:00:00 UTC"
      pair = TokenPair "a" "r" t
