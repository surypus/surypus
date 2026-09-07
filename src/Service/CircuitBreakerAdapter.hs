{-# LANGUAGE OverloadedStrings #-}
-- | Circuit-breaker integration seam (Phase 1: stub)
module Service.CircuitBreakerAdapter
  ( CircuitBreaker
  , newCircuitBreaker
  , withCircuitBreaker
  ) where

import Data.Text (Text)
import DAL.Database (ConnectionPool)

-- | Circuit breaker state (stub)
data CircuitBreaker = CircuitBreaker
  { cbFailureCount :: !Int
  , cbThreshold :: !Int
  }

-- | Create a new circuit breaker (stub)
newCircuitBreaker :: Int -> IO CircuitBreaker
newCircuitBreaker threshold = return $ CircuitBreaker 0 threshold

-- | Execute action with circuit breaker (stub)
withCircuitBreaker :: CircuitBreaker -> IO a -> IO (Either String a)
withCircuitBreaker _ action = do
  result <- action
  return $ Right result
