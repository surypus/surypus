-- | Unit and property-based tests for Transcendence monad transformer.
-- Tests the Transcendence newtype, its run/return/bind helpers,
-- and the Functor/Applicative/Monad/MonadTrans/MonadIO instances.
{-# LANGUAGE ScopedTypeVariables #-}
module TranscendenceSpec (spec) where

import Transcendence
  ( Transcendence
  , runTranscendence
  , returnT
  , bindT
  )
import Test.Hspec
import Test.QuickCheck
  ( Arbitrary (..)
  , Gen
  , property
  , choose
  )
import Test.QuickCheck.Monadic (monadicIO, run, assert, pick)
import Control.Monad.Trans.Class (MonadTrans (..))
import Control.Monad.IO.Class (MonadIO (..))

-- | Run a Transcendence IO computation.
runT :: Transcendence IO a -> IO a
runT = runTranscendence

spec :: Spec
spec = do
  describe "runTranscendence" runSpec
  describe "returnT" returnSpec
  describe "bindT" bindSpec
  describe "Monad laws" monadLawSpec
  describe "Functor laws" functorLawSpec
  describe "Applicative laws" applicativeLawSpec
  describe "MonadTrans lift" monadTransSpec
  describe "MonadIO liftIO" monadIOSpec

-- ============================================================================
-- runTranscendence basic behaviour
-- ============================================================================

runSpec :: Spec
runSpec = do
  it "returns the inner computation result" $
    runT (returnT (42 :: Int)) `shouldReturn` 42

  it "preserves identity" $
    runT (returnT "hello") `shouldReturn` ("hello" :: String)

  it "works with arithmetic" $ do
    result <- runT (returnT (1 + 2))
    result `shouldBe` (3 :: Int)

-- ============================================================================
-- returnT
-- ============================================================================

returnSpec :: Spec
returnSpec = do
  it "wraps a pure value" $
    runT (returnT True) `shouldReturn` True

  it "wraps zero" $
    runT (returnT (0 :: Int)) `shouldReturn` 0

-- ============================================================================
-- bindT
-- ============================================================================

bindSpec :: Spec
bindSpec = do
  it "chains computations" $
    runT (returnT (10 :: Int) >>= \x -> returnT (x + 5)) `shouldReturn` 15

  it "left identity: returnT a >>= f ≡ f a" $
    property $ monadicIO $ do
      a <- pick (choose (-100, 100) :: Gen Int)
      x <- run (runT (returnT a >>= \v -> returnT (v + 1)))
      y <- run (runT (returnT (a + 1)))
      assert (x == y)

  it "right identity: m >>= returnT ≡ m" $
    property $ monadicIO $ do
      a <- pick (choose (-100, 100) :: Gen Int)
      let m = returnT a
      x <- run (runT (m >>= returnT))
      y <- run (runT m)
      assert (x == y)

  it "associativity: (m >>= f) >>= g ≡ m >>= (\\x -> f x >>= g)" $
    property $ monadicIO $ do
      a <- pick (choose (-100, 100) :: Gen Int)
      let m = returnT a
      x <- run (runT ((m >>= \v -> returnT (v + 1)) >>= \v -> returnT (v * 2)))
      y <- run (runT (m >>= \a' -> returnT (a' + 1) >>= \v -> returnT (v * 2)))
      assert (x == y)

-- ============================================================================
-- Monad laws (explicit, for clarity)
-- ============================================================================

monadLawSpec :: Spec
monadLawSpec = do
  it "left identity" $
    property $ monadicIO $ do
      a <- pick (choose (-100, 100) :: Gen Int)
      x <- run (runT (returnT a >>= \v -> returnT (v + 1)))
      y <- run (runT (returnT (a + 1)))
      assert (x == y)

  it "right identity" $
    property $ monadicIO $ do
      a <- pick (choose (-100, 100) :: Gen Int)
      let m = returnT a
      x <- run (runT (m >>= returnT))
      y <- run (runT m)
      assert (x == y)

  it "associativity" $
    property $ monadicIO $ do
      a <- pick (choose (-100, 100) :: Gen Int)
      let m = returnT a
      x <- run (runT ((m >>= \v -> returnT (v + 1)) >>= \v -> returnT (v * 2)))
      y <- run (runT (m >>= \a' -> returnT (a' + 1) >>= \v -> returnT (v * 2)))
      assert (x == y)

-- ============================================================================
-- Functor laws
-- ============================================================================

functorLawSpec :: Spec
functorLawSpec = do
  it "identity: fmap id ≡ id" $
    property $ monadicIO $ do
      a <- pick (choose (-100, 100) :: Gen Int)
      let m = returnT a
      x <- run (runT (fmap id m))
      y <- run (runT m)
      assert (x == y)

  it "composition: fmap (f . g) ≡ fmap f . fmap g" $
    property $ monadicIO $ do
      a <- pick (choose (-100, 100) :: Gen Int)
      let m = returnT a
      x <- run (runT (fmap (\v -> (v * 2) + 1) m))
      y <- run (runT (fmap (+ 1) (fmap (* 2) m)))
      assert (x == y)

-- ============================================================================
-- Applicative laws
-- ============================================================================

applicativeLawSpec :: Spec
applicativeLawSpec = do
  it "identity: pure id <*> v ≡ v" $
    property $ monadicIO $ do
      a <- pick (choose (-100, 100) :: Gen Int)
      let v = returnT a
      x <- run (runT (pure id <*> v))
      y <- run (runT v)
      assert (x == y)

  it "homomorphism: pure f <*> pure x ≡ pure (f x)" $
    property $ monadicIO $ do
      x <- pick (choose (-100, 100) :: Gen Int)
      a <- run (runT (pure (+ 1) <*> pure x))
      b <- run (runT (pure (x + 1)))
      assert (a == b)

  it "interchange: u <*> pure y ≡ pure ($ y) <*> u" $
    property $ monadicIO $ do
      y <- pick (choose (-100, 100) :: Gen Int)
      let u = returnT (+ 1)
      a <- run (runT (u <*> pure y))
      b <- run (runT (pure ($ y) <*> u))
      assert (a == b)

  it "composition: pure (.) <*> u <*> v <*> w ≡ u <*> (v <*> w)" $
    property $ monadicIO $ do
      let u = returnT (+ 1)
      let v = returnT (* 2)
      w <- pick (choose (-100, 100) :: Gen Int)
      a <- run (runT (pure (.) <*> u <*> v <*> pure w))
      b <- run (runT (u <*> (v <*> pure w)))
      assert (a == b)

-- ============================================================================
-- MonadTrans lift
-- ============================================================================

monadTransSpec :: Spec
monadTransSpec = do
  it "lift wraps a pure value" $
    property $ monadicIO $ do
      x <- pick (choose (-100, 100) :: Gen Int)
      a <- run (runT (lift (pure x)))
      b <- run (pure x)
      assert (a == b)

  it "lift preserves the computation" $ do
    result <- runT (lift (pure (100 :: Int)))
    result `shouldBe` 100

-- ============================================================================
-- MonadIO liftIO
-- ============================================================================

monadIOSpec :: Spec
monadIOSpec = do
  it "liftIO runs a pure computation" $
    property $ monadicIO $ do
      x <- pick (choose (-100, 100) :: Gen Int)
      a <- run (runT (liftIO (pure x)))
      b <- run (pure x)
      assert (a == b)

  it "liftIO with actual IO" $ do
    result <- runT (liftIO (readFile "/dev/null" >>= \s -> pure (length s)))
    result `shouldBe` (0 :: Int)
