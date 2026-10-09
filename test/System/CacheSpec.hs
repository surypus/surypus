{-# LANGUAGE OverloadedStrings #-}

-- | Unit tests for System.Cache — pure cache operations and tax helpers.
module System.CacheSpec (spec) where

import Control.Concurrent.STM (atomically)
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import System.Cache
import Test.Hspec

testTime :: UTCTime
testTime = UTCTime (fromGregorian 2025 1 1) (secondsToDiffTime 0)

pastTime :: UTCTime
pastTime = UTCTime (fromGregorian 2024 1 1) (secondsToDiffTime 0)

futureTime :: UTCTime
futureTime = UTCTime (fromGregorian 2026 1 1) (secondsToDiffTime 0)

spec :: Spec
spec = do
  describe "calcHitRate" $ do
    it "returns 0 for empty stats" $
      calcHitRate (CacheStats 0 0 0) `shouldBe` 0.0
    it "returns 0.75 for 75 hits / 25 misses" $
      calcHitRate (CacheStats 75 25 0) `shouldBe` 0.75
    it "returns 1.0 for all hits" $
      calcHitRate (CacheStats 100 0 0) `shouldBe` 1.0

  describe "isExpired" $ do
    it "returns False when no expiry is set" $
      isExpired (CacheEntry "k" (1 :: Int) Nothing) testTime `shouldBe` False
    it "returns True when expiry is in the past" $
      isExpired (CacheEntry "k" (1 :: Int) (Just pastTime)) testTime `shouldBe` True
    it "returns False when expiry is in the future" $
      isExpired (CacheEntry "k" (1 :: Int) (Just futureTime)) testTime `shouldBe` False

  describe "calcVATStrict" $ do
    it "calculates 20% VAT on 100" $
      calcVATStrict 100 20 `shouldBe` 20.0
    it "calculates 0% VAT" $
      calcVATStrict 100 0 `shouldBe` 0.0
    it "calculates 100% VAT" $
      calcVATStrict 50 100 `shouldBe` 50.0

  describe "calcTaxInclusiveStrict" $ do
    it "adds 20% to 100" $
      calcTaxInclusiveStrict 100 20 `shouldBe` 120.0
    it "adds 0% to 100" $
      calcTaxInclusiveStrict 100 0 `shouldBe` 100.0
    it "adds 100% to 50" $
      calcTaxInclusiveStrict 50 100 `shouldBe` 100.0

  describe "STMCache" $ do
    it "creates empty cache" $ do
      cache <- newSTMCache 10 :: IO (STMCache String Int)
      size <- atomically $ stmCacheSize cache
      size `shouldBe` 0

    it "stores and retrieves values" $ do
      cache <- newSTMCache 10 :: IO (STMCache String Int)
      atomically $ stmCachePut "a" 42 cache
      result <- atomically $ stmCacheGet "a" cache
      result `shouldBe` Just 42

    it "returns Nothing for missing keys" $ do
      cache <- newSTMCache 10 :: IO (STMCache String Int)
      result <- atomically $ stmCacheGet "missing" cache
      result `shouldBe` Nothing

    it "overwrites existing entries" $ do
      cache <- newSTMCache 10 :: IO (STMCache String Int)
      atomically $ do
        stmCachePut "a" 1 cache
        stmCachePut "a" 2 cache
      result <- atomically $ stmCacheGet "a" cache
      result `shouldBe` Just 2

    it "respects maxSize" $ do
      cache <- newSTMCache 2 :: IO (STMCache String Int)
      atomically $ do
        stmCachePut "a" 1 cache
        stmCachePut "b" 2 cache
        stmCachePut "c" 3 cache
      size <- atomically $ stmCacheSize cache
      size `shouldBe` 2

    it "deletes entries" $ do
      cache <- newSTMCache 10 :: IO (STMCache String Int)
      atomically $ do
        stmCachePut "a" 1 cache
        stmCacheDelete "a" cache
      result <- atomically $ stmCacheGet "a" cache
      result `shouldBe` Nothing

    it "clears all entries" $ do
      cache <- newSTMCache 10 :: IO (STMCache String Int)
      atomically $ do
        stmCachePut "a" 1 cache
        stmCachePut "b" 2 cache
        stmCacheClear cache
      size <- atomically $ stmCacheSize cache
      size `shouldBe` 0
