{-# LANGUAGE DeriveGeneric #-}
module Surypus.Domain.Observability.Domain where

import GHC.Generics (Generic)
import Surypus.Domain.Observability.Types

-- Minimal observability hooks (placeholders for metrics collection)
recordLatency :: Double -> IO ()
recordLatency _ = return ()

recordBacklog :: Int -> IO ()
recordBacklog _ = return ()

recordThroughput :: Int -> IO ()
recordThroughput _ = return ()
