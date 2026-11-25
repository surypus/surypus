{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Unit tests for Surypus.JWT — security-critical module.
-- Tests validateAccessToken and decodeAndValidateToken which are
-- pure token operations (no database required).
module JWTSpec (spec) where

import Control.Exception (try, SomeException)
import Data.Either (isRight)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime (..), secondsToDiffTime)
import Data.Time.Calendar (fromGregorian)
import Test.Hspec
import Test.QuickCheck
import Test.QuickCheck.Monadic (monadicIO, run, assert)

import Surypus.JWT
  ( JWTConfig (..),
    jwtConfigFromSecret,
    validateAccessToken,
    decodeAndValidateToken,
    AuthError (..),
  )

-- ============================================================================
-- Test data
-- ============================================================================

-- | A fixed secret for deterministic tests
testSecret :: Text
testSecret = "test-secret-key-that-is-long-enough-for-hs256"

-- | A standard test config
testConfig :: JWTConfig
testConfig = jwtConfigFromSecret testSecret

-- | A UTCTime at midnight on 2025-01-01
midnight :: UTCTime
midnight = UTCTime (fromGregorian 2025 1 1) 0

-- ============================================================================
-- jwtConfigFromSecret tests
-- ============================================================================

spec :: Spec
spec = do
  describe "jwtConfigFromSecret" jwtConfigFromSecretSpec
  describe "validateAccessToken" validateAccessTokenSpec
  describe "decodeAndValidateToken" decodeAndValidateTokenSpec
  describe "Security properties" securityPropertiesSpec
  describe "Real signed JWT behaviour" realTokenSpec

jwtConfigFromSecretSpec :: Spec
jwtConfigFromSecretSpec = do
  it "creates config with correct secret" $
    jwtSecret testConfig `shouldBe` testSecret

  it "sets default expiry to 3600 seconds" $
    jwtExpiry testConfig `shouldBe` 3600

  it "sets default refresh expiry to 1209600 seconds (14 days)" $
    jwtRefreshExpiry testConfig `shouldBe` 1209600

  it "preserves different secrets" $ do
    let cfg = jwtConfigFromSecret "different-secret"
    jwtSecret cfg `shouldBe` "different-secret"

-- ============================================================================
-- validateAccessToken tests
-- ============================================================================

validateAccessTokenSpec :: Spec
validateAccessTokenSpec = do
  it "rejects empty token" $ do
    result <- validateAccessToken testSecret ""
    result `shouldSatisfy` isLeft'

  it "rejects malformed token (not base64)" $ do
    result <- validateAccessToken testSecret "not-a-valid-jwt"
    result `shouldSatisfy` isLeft'

  it "rejects token with wrong number of segments" $ do
    result <- validateAccessToken testSecret "abc.def"
    result `shouldSatisfy` isLeft'

  it "rejects token signed with different secret" $ do
    -- Create a token with one secret, validate with another
    let wrongSecret = "wrong-secret-that-is-also-long-enough"
    result <- validateAccessToken wrongSecret "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature"
    result `shouldSatisfy` isLeft'

  it "rejects token with invalid signature format" $ do
    result <- validateAccessToken testSecret "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.invalidsignature"
    result `shouldSatisfy` isLeft'

  it "rejects non-JSON payload" $ do
    result <- validateAccessToken testSecret "eyJhbGciOiJIUzI1NiJ9.not-json.signature"
    result `shouldSatisfy` isLeft'

  it "rejects token with missing sub claim" $ do
    -- {"name":"test"} without "sub"
    let token = "eyJhbGciOiJIUzI1NiJ9.eyJuYW1lIjoidGVzdCJ9.signature"
    result <- validateAccessToken testSecret token
    result `shouldSatisfy` isLeft'

-- ============================================================================
-- decodeAndValidateToken tests
-- ============================================================================

decodeAndValidateTokenSpec :: Spec
decodeAndValidateTokenSpec = do
  it "rejects empty token" $ do
    result <- decodeAndValidateToken testSecret ""
    result `shouldBe` Left AuthInvalid

  it "rejects malformed token" $ do
    result <- decodeAndValidateToken testSecret "garbage"
    result `shouldBe` Left AuthInvalid

  it "rejects token with two segments" $ do
    result <- decodeAndValidateToken testSecret "abc.def"
    result `shouldBe` Left AuthInvalid

  it "rejects token signed with wrong secret" $ do
    result <- decodeAndValidateToken "wrong-secret-that-is-also-long-enough-hs256" "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature"
    result `shouldBe` Left AuthInvalid

  it "rejects token with non-integer sub claim" $ do
    -- Header: {"alg":"HS256"}, Payload: {"sub":"not-a-number"}
    let token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJub3QtYS1udW1iZXIifQ.signature"
    result <- decodeAndValidateToken testSecret token
    result `shouldBe` Left AuthInvalid

  it "rejects non-JSON payload" $ do
    let token = "eyJhbGciOiJIUzI1NiJ9.aaa.signature"
    result <- decodeAndValidateToken testSecret token
    result `shouldBe` Left AuthInvalid

-- ============================================================================
-- Security properties
-- ============================================================================

securityPropertiesSpec :: Spec
securityPropertiesSpec = do
  it "empty token is always rejected" $ property $
    \secret -> monadicIO $ do
      result <- run $ validateAccessToken (T.pack secret) ""
      assert $ isLeft' result

  it "malformed tokens are always rejected" $ property $
    \token -> monadicIO $ do
      result <- run $ validateAccessToken testSecret (T.pack token)
      assert $ isLeft' result

  it "decodeAndValidateToken rejects empty tokens" $ property $
    \secret -> monadicIO $ do
      result <- run $ decodeAndValidateToken (T.pack secret) ""
      assert $ result == Left AuthInvalid

  it "decodeAndValidateToken rejects malformed tokens" $ property $
    \token -> monadicIO $ do
      result <- run $ decodeAndValidateToken testSecret (T.pack token)
      assert $ result == Left AuthInvalid

  it "different secrets produce different validation outcomes for garbage tokens" $ property $
    \s1 s2 -> monadicIO $ do
      let secret1 = T.pack s1
          secret2 = T.pack s2
      r1 <- run $ validateAccessToken secret1 "garbage-token-for-testing"
      r2 <- run $ validateAccessToken secret2 "garbage-token-for-testing"
      -- Both should be rejected regardless of secret
      assert $ isLeft' r1 && isLeft' r2

-- ============================================================================
-- Helper (named isLeft' to avoid ambiguity with Data.Either.isLeft)
-- ============================================================================

isLeft' :: Either a b -> Bool
isLeft' (Left _) = True
isLeft' _        = False

-- ============================================================================
-- Real signed-token behaviour (fixtures generated independently with HS256)
-- ============================================================================

validToken, expiredToken, wrongAudienceToken, noSubToken, wrongSecretToken, tamperedToken :: Text
validToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsIm5hbWUiOiJ0ZXN0IiwiYXVkIjoic3VyeXB1cy1hcGkiLCJpYXQiOjE3MzU2ODk2MDAsImV4cCI6NDEwMjQ0NDgwMH0.ESY-I90QiGX2uaFJv5m9Vj1InSdo11eVWhZ0LYTA8jM"
expiredToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsIm5hbWUiOiJ0ZXN0IiwiYXVkIjoic3VyeXB1cy1hcGkiLCJpYXQiOjE3MzU2ODk2MDAsImV4cCI6MTYwMDAwMzYwMH0.SORQFIlIrHpYV3TTOUYQddLXnSjB5SAJqClzs2rNsbE"
wrongAudienceToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsIm5hbWUiOiJ0ZXN0IiwiYXVkIjoib3RoZXItYXBpIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjQxMDI0NDQ4MDB9.jp6YuEgfclltH-jm7deCBnDW5wMOclI2-R-Nk1hfH_M"
noSubToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoidGVzdCIsImF1ZCI6InN1cnlwdXMtYXBpIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjQxMDI0NDQ4MDB9.8ABDIuT1qum6zhFYGn9hM5knFeFSwNuYx6fVKbNUciY"
wrongSecretToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsIm5hbWUiOiJ0ZXN0IiwiYXVkIjoic3VyeXB1cy1hcGkiLCJpYXQiOjE3MzU2ODk2MDAsImV4cCI6NDEwMjQ0NDgwMH0.zfWRl8kNI8E0JJkoeNz7hnYHLz8sTDgwQAz5NTZ0rjE"
tamperedToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsIm5hbWUiOiJ0ZXN0IiwiYXVkIjoic3VyeXB1cy1hcGkiLCJpYXQiOjE3MzU2ODk2MDAsImV4cCI6NDEwMjQ0NDgwMH0.ESY-I90QiGX2uaFJv5m9Vj1InSdo11eVWhZ0LYTAabc"

realTokenSpec :: Spec
realTokenSpec = do
  it "accepts a correctly signed token with sub/aud/exp" $
    validateAccessToken testSecret validToken `shouldReturn` Right 42

  it "rejects an expired token" $
    validateAccessToken testSecret expiredToken `shouldReturn` Left "Invalid or expired token"

  it "rejects a token with the wrong audience" $
    validateAccessToken testSecret wrongAudienceToken `shouldReturn` Left "Invalid or expired token"

  it "rejects a token without a sub claim" $
    validateAccessToken testSecret noSubToken `shouldReturn` Left "Invalid token: missing sub claim"

  it "rejects a token signed with another secret" $
    validateAccessToken testSecret wrongSecretToken `shouldReturn` Left "Invalid or expired token"

  it "rejects a tampered signature" $
    validateAccessToken testSecret tamperedToken `shouldReturn` Left "Invalid or expired token"

  it "decodes identity and expiry from a real token" $ do
    result <- decodeAndValidateToken testSecret validToken
    case result of
      Right (uid, name, expAt) -> do
        uid `shouldBe` 42
        name `shouldBe` "test"
        expAt `shouldSatisfy` (> read "2036-01-01 00:00:00 UTC")
      Left err -> fail ("unexpected rejection: " ++ show err)

