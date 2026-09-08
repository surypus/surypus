{-# LANGUAGE DeriveGeneric #-}
module Surypus.Domain.Observability.Types where

import Data.Text (Text)
import GHC.Generics (Generic)

data Metric
  = Latency Double
  | Backlog Int
  | Throughput Int
  deriving (Eq, Show, Generic)
