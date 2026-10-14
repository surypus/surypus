{-# LANGUAGE OverloadedStrings #-}

module System.CircuitBreakerSpec (spec) where

import Control.Concurrent.STM (atomically, readTVarIO, writeTVar)
import Control.Exception (throwIO)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.Text (Text)
import System.CircuitBreaker
import Test.Hspec

-- | Test config with fast transitions (resetTimeoutSec = 0)
testConfig :: CircuitConfig
testConfig =
  CircuitConfig
    { failureThresholdCount = 3,
      resetTimeoutSec = 0,
      halfOpenMaxCalls = 2,
      failureRateThreshold = 0.5,
      successThreshold = 0.8
    }

-- | Config that opens after a single failure
oneStrikeConfig :: CircuitConfig
oneStrikeConfig = testConfig {failureThresholdCount = 1}

spec :: Spec
spec = do
  describe "System.CircuitBreaker" $ do
    describe "initCircuitBreaker" $ do
      it "starts in closed state with zero threshold counter" $ do
        breaker <- initCircuitBreaker testConfig
        state <- getCircuitState breaker
        state `shouldBe` CBSClosed 0

    describe "executeWithCircuitBreaker" $ do
      it "returns Right on success and stays closed" $ do
        breaker <- initCircuitBreaker testConfig
        result <- executeWithCircuitBreaker breaker (return (42 :: Int))
        result `shouldBe` Right 42
        state <- getCircuitState breaker
        state `shouldBe` CBSClosed 0

      it "returns Left on failure with error text" $ do
        breaker <- initCircuitBreaker testConfig
        result <- executeWithCircuitBreaker breaker (ioError (userError "boom") :: IO Int)
        result `shouldSatisfy` isLeft
        state <- getCircuitState breaker
        state `shouldSatisfy` isOpenOrClosed

      it "opens circuit after failureThresholdCount failures" $ do
        breaker <- initCircuitBreaker (testConfig {failureThresholdCount = 2, resetTimeoutSec = 1})
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e1") :: IO Int)
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e2") :: IO Int)
        state <- getCircuitState breaker
        state `shouldSatisfy` isOpen

      it "returns Left 'Circuit open' when circuit is open" $ do
        breaker <- initCircuitBreaker (oneStrikeConfig {resetTimeoutSec = 1})
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e1") :: IO Int)
        result <- executeWithCircuitBreaker breaker (return (42 :: Int))
        result `shouldBe` Left "Circuit open"

      it "transitions to half-open after resetTimeoutSec (0 = immediate)" $ do
        breaker <- initCircuitBreaker oneStrikeConfig
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e1") :: IO Int)
        -- With resetTimeoutSec = 0, the next call transitions to half-open
        result <- executeWithCircuitBreaker breaker (return (42 :: Int))
        result `shouldBe` Right 42

      it "closes circuit on success in half-open state" $ do
        breaker <- initCircuitBreaker oneStrikeConfig
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e1") :: IO Int)
        _ <- executeWithCircuitBreaker breaker (return (42 :: Int))
        state <- getCircuitState breaker
        state `shouldBe` CBSClosed 0

      it "re-opens circuit on failure in half-open state" $ do
        breaker <- initCircuitBreaker oneStrikeConfig
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e1") :: IO Int)
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e2") :: IO Int)
        state <- getCircuitState breaker
        state `shouldSatisfy` isOpen

      it "tracks metrics on success" $ do
        breaker <- initCircuitBreaker testConfig
        _ <- executeWithCircuitBreaker breaker (return (42 :: Int))
        metrics <- readTVarIO (cbMetrics breaker)
        totalRequests metrics `shouldBe` 1
        totalSuccesses metrics `shouldBe` 1
        totalFailures metrics `shouldBe` 0

      it "tracks metrics on failure" $ do
        breaker <- initCircuitBreaker testConfig
        _ <- executeWithCircuitBreaker breaker (ioError (userError "boom") :: IO Int)
        metrics <- readTVarIO (cbMetrics breaker)
        totalRequests metrics `shouldBe` 1
        totalFailures metrics `shouldBe` 1
        totalSuccesses metrics `shouldBe` 0

      it "computes failure rate correctly after mixed results" $ do
        breaker <- initCircuitBreaker (testConfig {failureThresholdCount = 10})
        _ <- executeWithCircuitBreaker breaker (return (1 :: Int))
        _ <- executeWithCircuitBreaker breaker (return (2 :: Int))
        _ <- executeWithCircuitBreaker breaker (ioError (userError "fail") :: IO Int)
        metrics <- readTVarIO (cbMetrics breaker)
        totalRequests metrics `shouldBe` 3
        totalSuccesses metrics `shouldBe` 2
        totalFailures metrics `shouldBe` 1
        failureRate metrics `shouldBe` 1.0 / 3.0

      it "does not execute action when circuit is open" $ do
        breaker <- initCircuitBreaker (oneStrikeConfig {resetTimeoutSec = 1})
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e1") :: IO Int)
        -- This action should NOT be executed
        varRef <- newIORef False
        result <- executeWithCircuitBreaker breaker (writeIORef varRef True >> return 42)
        result `shouldBe` Left "Circuit open"
        val <- readIORef varRef
        val `shouldBe` False

      it "returns Left 'Circuit breaker disabled' when state is CBSDisabled" $ do
        breaker <- initCircuitBreaker testConfig
        atomically $ writeTVar (cbStateVar breaker) CBSDisabled
        result <- executeWithCircuitBreaker breaker (return (42 :: Int))
        result `shouldBe` Left "Circuit breaker disabled"

      it "does not execute action when circuit is disabled" $ do
        breaker <- initCircuitBreaker testConfig
        atomically $ writeTVar (cbStateVar breaker) CBSDisabled
        varRef <- newIORef False
        result <- executeWithCircuitBreaker breaker (writeIORef varRef True >> return 42)
        result `shouldBe` Left "Circuit breaker disabled"
        val <- readIORef varRef
        val `shouldBe` False

    describe "resetCircuitBreaker" $ do
      it "resets to closed state" $ do
        breaker <- initCircuitBreaker oneStrikeConfig
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e1") :: IO Int)
        resetCircuitBreaker breaker
        state <- getCircuitState breaker
        state `shouldBe` CBSClosed 0

      it "clears failure count" $ do
        breaker <- initCircuitBreaker (testConfig {failureThresholdCount = 2})
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e1") :: IO Int)
        resetCircuitBreaker breaker
        _ <- executeWithCircuitBreaker breaker (return (42 :: Int))
        state <- getCircuitState breaker
        state `shouldBe` CBSClosed 0

      it "resets metrics" $ do
        breaker <- initCircuitBreaker oneStrikeConfig
        _ <- executeWithCircuitBreaker breaker (ioError (userError "e1") :: IO Int)
        resetCircuitBreaker breaker
        metrics <- readTVarIO (cbMetrics breaker)
        totalRequests metrics `shouldBe` 0
        totalFailures metrics `shouldBe` 0
        totalSuccesses metrics `shouldBe` 0
        failureRate metrics `shouldBe` 0

  where
    isOpen CBSOpen {} = True
    isOpen _ = False

    isOpenOrClosed CBSOpen {} = True
    isOpenOrClosed CBSClosed {} = True
    isOpenOrClosed _ = False

    isLeft (Left _) = True
    isLeft _ = False
