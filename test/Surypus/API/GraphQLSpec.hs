{-# LANGUAGE OverloadedStrings #-}

-- | Tests for the GraphQL proxy (US-3-4).
--
-- The proxy resolves an operation name to the same query the REST endpoint
-- runs. These tests cover the paths that need no database; the operation
-- dispatch itself is covered by the REST endpoint tests.
module Surypus.API.GraphQLSpec (spec) where

import Control.Monad.Logger (runNoLoggingT)
import Data.Aeson (Value, object, (.=))
import Data.ByteString.Char8 (pack)
import Data.Text (Text)
import Database.Persist.Postgresql (createPostgresqlPool)
import Surypus.API.GraphQL (resolveQuery)
import Test.Hspec

spec :: Spec
spec = do
  describe "resolveQuery" $ do
    it "rejects an empty query" $ do
      pool <- newPool
      result <- resolveQuery pool ""
      result `shouldBe` Left "Empty query"

    it "rejects a whitespace-only query" $ do
      pool <- newPool
      result <- resolveQuery pool "   "
      result `shouldBe` Left "Empty query"

    it "reports an unknown operation" $ do
      pool <- newPool
      result <- resolveQuery pool "noSuchOperation"
      case result of
        Left err -> expectationFailure ("unexpected error: " ++ show err)
        Right val ->
          val `shouldBe` object ["message" .= ("Unknown operation: noSuchOperation" :: Text)]

    it "treats the first word as the operation name" $ do
      pool <- newPool
      result <- resolveQuery pool "  bogus  "
      case result of
        Left err -> expectationFailure ("unexpected error: " ++ show err)
        Right val ->
          val `shouldBe` object ["message" .= ("Unknown operation: bogus" :: Text)]

  where
    newPool = runNoLoggingT $ createPostgresqlPool (pack "host=127.0.0.1 port=1 dbname=x user=x password=x") 1
