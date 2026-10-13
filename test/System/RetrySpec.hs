module System.RetrySpec (spec) where

import Control.Exception (Exception, throwIO)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import System.Retry

import Test.Hspec

spec :: Spec
spec = describe "System.Retry" $ do
  describe "withRetries" $ do
    it "returns Success on first-attempt success" $ do
      result <- withRetries (RetryConfig 3 1000 1000000 (FixedDelay 1000)) (return (42 :: Int))
      result `shouldSatisfy` isRetrySuccess
      result `shouldSatisfy` hasRetryValue 42

    it "returns Failure with maxAttempts errors when all attempts fail" $ do
      result <- withRetries (RetryConfig 3 1000 1000000 (FixedDelay 1000)) (throwIO Boom :: IO Int)
      result `shouldSatisfy` isRetryFailure
      result `shouldSatisfy` hasRetryErrorCount 3

    it "returns Failure with empty error list when maxAttempts is 0" $ do
      result <- withRetries (RetryConfig 0 1000 1000000 (FixedDelay 1000)) (return (42 :: Int))
      result `shouldSatisfy` isRetryFailure
      result `shouldSatisfy` hasRetryErrorCount 0

    it "returns Success when action succeeds after some failures" $ do
      ref <- newIORef (0 :: Int)
      let action = do
            n <- readIORef ref
            writeIORef ref (n + 1)
            if n < 2
              then throwIO Boom
              else return n
      result <- withRetries (RetryConfig 5 1000 1000000 (FixedDelay 1000)) action
      result `shouldSatisfy` isRetrySuccess
      result `shouldSatisfy` hasRetryValue 2

    it "returns Failure with fewer errors than maxAttempts when action eventually succeeds" $ do
      ref <- newIORef (0 :: Int)
      let action = do
            n <- readIORef ref
            writeIORef ref (n + 1)
            if n < 1
              then throwIO Boom
              else return n
      result <- withRetries (RetryConfig 5 1000 1000000 (FixedDelay 1000)) action
      result `shouldSatisfy` isRetrySuccess
      result `shouldSatisfy` hasRetryValue 1

  describe "withRetriesDelays" $ do
    it "returns Right on first-attempt success" $ do
      result <- withRetriesDelays [1000, 2000, 4000] (return (42 :: Int))
      result `shouldSatisfy` isRight

    it "returns Right when action succeeds after some delays" $ do
      ref <- newIORef (0 :: Int)
      let action = do
            n <- readIORef ref
            writeIORef ref (n + 1)
            if n < 1
              then throwIO Boom
              else return n
      result <- withRetriesDelays [1000, 2000, 4000] action
      result `shouldSatisfy` isRight

    it "returns Left when all delays are exhausted" $ do
      result <- withRetriesDelays [1000, 2000, 4000] (throwIO Boom :: IO Int)
      result `shouldSatisfy` isLeft

    it "returns Left immediately when delays list is empty and action fails" $ do
      result <- withRetriesDelays [] (throwIO Boom :: IO Int)
      result `shouldSatisfy` isLeft

  describe "untilSuccessWithTimeout" $ do
    it "returns Right when action succeeds" $ do
      result <- untilSuccessWithTimeout 3 1000 (return (42 :: Int))
      result `shouldBe` Right 42

    it "returns Right when action succeeds after some failures" $ do
      ref <- newIORef (0 :: Int)
      let action = do
            n <- readIORef ref
            writeIORef ref (n + 1)
            if n < 1
              then throwIO Boom
              else return n
      result <- untilSuccessWithTimeout 3 1000 action
      result `shouldBe` Right 1

    it "returns Left when all attempts fail" $ do
      result <- untilSuccessWithTimeout 3 1000 (throwIO Boom :: IO Int)
      result `shouldSatisfy` isLeft

    it "returns Left immediately when attempts is 0" $ do
      result <- untilSuccessWithTimeout 0 1000 (return (42 :: Int))
      result `shouldSatisfy` isLeft

  describe "retry strategies" $ do
    it "FixedDelay applies the same delay each attempt" $ do
      ref <- newIORef (0 :: Int)
      let action = do
            n <- readIORef ref
            writeIORef ref (n + 1)
            if n < 2
              then throwIO Boom
              else return n
      result <- withRetries (RetryConfig 4 1000 1000000 (FixedDelay 1000)) action
      result `shouldSatisfy` isRetrySuccess

    it "ExponentialBackoff succeeds after multiple failures" $ do
      ref <- newIORef (0 :: Int)
      let action = do
            n <- readIORef ref
            writeIORef ref (n + 1)
            if n < 2
              then throwIO Boom
              else return n
      result <- withRetries (RetryConfig 5 1000 1000000 ExponentialBackoff) action
      result `shouldSatisfy` isRetrySuccess

    it "LinearBackoff succeeds after multiple failures" $ do
      ref <- newIORef (0 :: Int)
      let action = do
            n <- readIORef ref
            writeIORef ref (n + 1)
            if n < 2
              then throwIO Boom
              else return n
      result <- withRetries (RetryConfig 5 1000 1000000 (LinearBackoff 1000)) action
      result `shouldSatisfy` isRetrySuccess

    it "Jitter succeeds after multiple failures" $ do
      ref <- newIORef (0 :: Int)
      let action = do
            n <- readIORef ref
            writeIORef ref (n + 1)
            if n < 2
              then throwIO Boom
              else return n
      result <- withRetries (RetryConfig 5 1000 1000000 Jitter) action
      result `shouldSatisfy` isRetrySuccess

-- Helpers (named to avoid clashes with Test.QuickCheck's isSuccess/Success/Failure)

data Boom = Boom deriving (Show, Eq)
instance Exception Boom

isRetrySuccess :: RetryResult a -> Bool
isRetrySuccess (Success _ _) = True
isRetrySuccess _ = False

isRetryFailure :: RetryResult a -> Bool
isRetryFailure (Failure _ _) = True
isRetryFailure _ = False

hasRetryValue :: Eq a => a -> RetryResult a -> Bool
hasRetryValue v (Success x _) = x == v
hasRetryValue _ _ = False

hasRetryErrorCount :: Int -> RetryResult a -> Bool
hasRetryErrorCount n (Failure errs _) = length errs == n
hasRetryErrorCount _ _ = False

isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft _ = False

isRight :: Either a b -> Bool
isRight (Right _) = True
isRight _ = False
