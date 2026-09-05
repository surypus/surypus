{-# LANGUAGE DeriveGeneric #-}
module Surypus.Domain.Observability.API where

import Surypus.Domain.Observability.Types

getSampleMetrics :: [Metric]
getSampleMetrics = [Latency 0.0, Backlog 0, Throughput 0]
