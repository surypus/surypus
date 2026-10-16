{-# LANGUAGE OverloadedStrings #-}

-- | Unit tests for Integration.API.ExternalAPI.
--
-- The network paths need a live server, so only the pure helpers and the
-- retry/error plumbing are covered here.
module Integration.API.ExternalAPISpec (spec) where

import Control.Exception (SomeException (..), throwIO)
import Data.Either (fromRight, isLeft, isRight)
import Data.IORef (newIORef, readIORef, modifyIORef)
import qualified Integration.API.ExternalAPI as API
import Network.HTTP.Client (requestHeaders)
import Network.HTTP.Simple (parseRequest)
import Network.HTTP.Types.Header (hAuthorization)
import System.IO.Error (userError)
import Test.Hspec

spec :: Spec
spec = do
  describe "attachApiKey" $ do
    it "adds a Bearer token when a key is configured" $ do
      req <- parseRequest "http://example.com"
      lookup hAuthorization (requestHeaders (API.attachApiKey (Just "secret") req))
        `shouldBe` Just "Bearer secret"

    it "leaves the request alone when no key is configured" $ do
      req <- parseRequest "http://example.com"
      requestHeaders (API.attachApiKey Nothing req) `shouldBe` requestHeaders req

  describe "handleAPIError" $ do
    it "passes a successful value through" $
      API.handleAPIError (Right (42 :: Int)) `shouldBe` Right 42

    it "turns an exception into an error string" $
      API.handleAPIError (Left (SomeException (userError "boom")) :: Either SomeException Int)
        `shouldSatisfy` isLeft

  describe "retryRequest" $ do
    it "returns the first success without retrying" $ do
      ref <- newIORef (0 :: Int)
      result <- API.retryRequest 3 (modifyIORef ref (+ 1) >> pure (7 :: Int))
      result `shouldSatisfy` isRight
      fromRight 0 result `shouldBe` 7
      n <- readIORef ref
      n `shouldBe` 1

    it "retries until the action succeeds" $ do
      ref <- newIORef (0 :: Int)
      result <- API.retryRequest 5 $ do
        n <- modifyIORef ref (+ 1) >> readIORef ref
        if n < 3 then throwIO (userError "not yet") else pure n
      result `shouldSatisfy` isRight
      fromRight 0 result `shouldBe` 3
      n <- readIORef ref
      n `shouldBe` 3

    it "gives up after maxAttempts failures" $ do
      ref <- newIORef (0 :: Int)
      result <- API.retryRequest 2 $ do
        modifyIORef ref (+ 1)
        throwIO (userError "always") :: IO Int
      result `shouldSatisfy` isLeft
      n <- readIORef ref
      n `shouldBe` 2
