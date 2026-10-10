-- | Unit tests for Core.Accounting.Cache (US-3-3).
-- Tests the thread-safe in-memory STM cache with LRU eviction,
-- cache hit/miss statistics, and invalidation.
module Core.Accounting.CacheSpec (spec) where

import qualified Core.Accounting.Cache as C
import Test.Hspec
import Test.QuickCheck
import Test.QuickCheck.Monadic (monadicIO, run, assert)

spec :: Spec
spec = do
  describe "mkReadModelCache" $ do
    it "creates an empty cache with zero stats" $ do
      cache <- C.mkReadModelCache 10
      stats <- C.cacheStats cache
      C.csHits stats `shouldBe` 0
      C.csMisses stats `shouldBe` 0
      C.csSize stats `shouldBe` 0

    it "creates a cache that accepts inserts" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 1 100.0
      bal <- C.getCachedBalance cache 1
      bal `shouldBe` 100.0

  describe "getCachedBalance" $ do
    it "returns 0.0 for missing key" $ do
      cache <- C.mkReadModelCache 10
      bal <- C.getCachedBalance cache 99
      bal `shouldBe` 0.0

    it "returns stored value for existing key" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 42 4242.0
      bal <- C.getCachedBalance cache 42
      bal `shouldBe` 4242.0

    it "tracks hit on successful lookup" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 1 500.0
      _ <- C.getCachedBalance cache 1
      stats <- C.cacheStats cache
      C.csHits stats `shouldSatisfy` (>= 1)

    it "tracks miss on failed lookup" $ do
      cache <- C.mkReadModelCache 10
      _ <- C.getCachedBalance cache 1
      stats <- C.cacheStats cache
      C.csMisses stats `shouldSatisfy` (>= 1)

  describe "putCachedBalance" $ do
    it "overwrites existing entry" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 1 100.0
      C.putCachedBalance cache 1 200.0
      bal <- C.getCachedBalance cache 1
      bal `shouldBe` 200.0

    it "stores multiple independent entries" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 1 100.0
      C.putCachedBalance cache 2 200.0
      b1 <- C.getCachedBalance cache 1
      b2 <- C.getCachedBalance cache 2
      b1 `shouldBe` 100.0
      b2 `shouldBe` 200.0

    it "respects maxSize with LRU eviction" $ do
      cache <- C.mkReadModelCache 2
      C.putCachedBalance cache 1 100.0
      C.putCachedBalance cache 2 200.0
      C.putCachedBalance cache 3 300.0  -- should evict key 1
      b1 <- C.getCachedBalance cache 1
      b3 <- C.getCachedBalance cache 3
      b1 `shouldBe` 0.0
      b3 `shouldBe` 300.0

  describe "invalidateCache" $ do
    it "removes an entry" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 1 100.0
      C.invalidateCache cache 1
      bal <- C.getCachedBalance cache 1
      bal `shouldBe` 0.0

    it "does not affect other entries" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 1 100.0
      C.putCachedBalance cache 2 200.0
      C.invalidateCache cache 1
      b2 <- C.getCachedBalance cache 2
      b2 `shouldBe` 200.0

  describe "clearCache" $ do
    it "removes all entries" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 1 100.0
      C.putCachedBalance cache 2 200.0
      C.clearCache cache
      b1 <- C.getCachedBalance cache 1
      b2 <- C.getCachedBalance cache 2
      b1 `shouldBe` 0.0
      b2 `shouldBe` 0.0

    it "reports zero size after clear" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 1 100.0
      C.clearCache cache
      stats <- C.cacheStats cache
      C.csSize stats `shouldBe` 0

  describe "cacheStats" $ do
    it "reflects correct size after inserts" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 1 100.0
      C.putCachedBalance cache 2 200.0
      stats <- C.cacheStats cache
      C.csSize stats `shouldBe` 2

    it "tracks hit rate after mixed access" $ do
      cache <- C.mkReadModelCache 10
      C.putCachedBalance cache 1 100.0
      _ <- C.getCachedBalance cache 1  -- hit
      _ <- C.getCachedBalance cache 2  -- miss
      _ <- C.getCachedBalance cache 1  -- hit
      stats <- C.cacheStats cache
      C.csHits stats `shouldBe` 2
      C.csMisses stats `shouldBe` 1

  describe "Properties" $ do
    it "put then get returns same value" $
      property $ \(Positive maxSize) key val ->
        monadicIO $ do
          cache <- run $ C.mkReadModelCache maxSize
          run $ C.putCachedBalance cache key val
          bal <- run $ C.getCachedBalance cache key
          assert $ bal == val

    it "get on empty cache returns 0" $
      property $ \(Positive maxSize) key ->
        monadicIO $ do
          cache <- run $ C.mkReadModelCache maxSize
          bal <- run $ C.getCachedBalance cache key
          assert $ bal == (0.0 :: Double)

    it "invalidate removes entry" $
      property $ \(Positive maxSize) key val ->
        monadicIO $ do
          cache <- run $ C.mkReadModelCache maxSize
          run $ C.putCachedBalance cache key val
          run $ C.invalidateCache cache key
          bal <- run $ C.getCachedBalance cache key
          assert $ bal == (0.0 :: Double)