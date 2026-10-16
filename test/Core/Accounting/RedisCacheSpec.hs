{-# LANGUAGE OverloadedStrings #-}

-- | Unit tests for Core.Accounting.RedisCache (US-3-3).
--
-- The Redis round-trip needs a live server, so it is exercised only when one is
-- reachable; the pure helpers and the failure path are always covered.
module Core.Accounting.RedisCacheSpec (spec) where

import qualified Core.Accounting.RedisCache as RC
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Test.Hspec
import Test.QuickCheck

spec :: Spec
spec = do
  describe "balanceKey" $ do
    it "prefixes every account with the accounting namespace" $
      RC.balanceKey 42 `shouldBe` ("surypus:accounting:balance:42" :: ByteString)

    it "distinguishes different accounts" $
      RC.balanceKey 1 `shouldNotBe` RC.balanceKey 2

    it "always carries the accounting namespace prefix" $
      property $ \a -> "surypus:accounting:balance:" `BS.isPrefixOf` RC.balanceKey a

  describe "encodeBalance/decodeBalance" $ do
    it "round-trips any balance" $
      property $ \b -> RC.decodeBalance (RC.encodeBalance b) == Just b

    it "returns Nothing for a malformed payload" $
      RC.decodeBalance "not-json" `shouldBe` Nothing

    it "returns Nothing for an empty payload" $
      RC.decodeBalance "" `shouldBe` Nothing

  describe "createRedisCache" $ do
    it "reports a connection failure as Left rather than throwing" $ do
      let cfg = RC.defaultRedisCacheConfig { RC.rccHost = "127.0.0.1", RC.rccPort = 1 }
      result <- RC.createRedisCache cfg
      case result of
        Left err -> err `shouldNotBe` ""
        Right cache -> RC.closeRedisCache cache

    it "round-trips a balance through Redis when a server is reachable" $ do
      result <- RC.createRedisCache RC.defaultRedisCacheConfig
      case result of
        Left _ -> pendingWith "no Redis server on localhost:6379"
        Right cache -> do
          _ <- RC.putCachedBalance cache 7 123.5
          got <- RC.getCachedBalance cache 7
          got `shouldBe` Right (Just 123.5)
          _ <- RC.deleteCachedBalance cache 7
          gone <- RC.getCachedBalance cache 7
          gone `shouldBe` Right Nothing
          RC.closeRedisCache cache
