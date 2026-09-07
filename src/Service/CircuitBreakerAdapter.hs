{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
-- | Circuit-breaker integration seam for repository / external actions.
--
-- The circuit breaker in 'System.CircuitBreaker' is a complete closed/open/
-- half-open implementation, but it has no call sites. This module provides a
-- drop-in adapter so any 'ConnectionPool -> IO a' action (DB query, mutation,
-- or external integration call) can be executed under breaker protection.
--
-- Example:
--
-- > br <- initCircuitBreaker defaultCircuitConfig
-- > result <- runDBWithCircuitBreaker br pool $ \p -> Mutations.createBill p input
--
-- On repeated failures the breaker opens and fast-fails subsequent calls until
-- the reset timeout elapses, after which a single trial call (half-open) decides
-- whether to close the circuit again.
module Service.CircuitBreakerAdapter
  ( defaultCircuitConfig,
    runDBWithCircuitBreaker,
    runActionWithCircuitBreaker,
  )
where

import Control.Monad.IO.Class (liftIO)
import DAL.Database (ConnectionPool)
import Data.Text (Text)
import System.CircuitBreaker
  ( CircuitBreaker (..),
    CircuitConfig (..),
    executeWithCircuitBreaker,
    initCircuitBreaker,
  )

-- | Sensible production defaults: open after 5 failures within the window,
-- allow a half-open trial after 30 seconds, permit a single half-open call.
defaultCircuitConfig :: CircuitConfig
defaultCircuitConfig =
  CircuitConfig
    { failureThresholdCount = 5,
      resetTimeoutSec = 30,
      halfOpenMaxCalls = 1,
      failureRateThreshold = 0.5,
      successThreshold = 0.8
    }

-- | Run a DB action under circuit-breaker protection.
-- Returns 'Left' with the breaker state/reason when the circuit is open or the
-- action throws; 'Right' on success.
runDBWithCircuitBreaker ::
  CircuitBreaker -> ConnectionPool -> (ConnectionPool -> IO a) -> IO (Either Text a)
runDBWithCircuitBreaker breaker pool action =
  executeWithCircuitBreaker breaker (action pool)

-- | Run an arbitrary IO action under circuit-breaker protection.
runActionWithCircuitBreaker ::
  CircuitBreaker -> IO a -> IO (Either Text a)
runActionWithCircuitBreaker = executeWithCircuitBreaker
