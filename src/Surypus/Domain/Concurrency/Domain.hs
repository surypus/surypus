{-# LANGUAGE DeriveGeneric #-}
module Surypus.Domain.Concurrency.Domain where

import GHC.Generics (Generic)

-- Lightweight concurrency primitives placeholders
startCanonicalizeAll :: IO ()
startCanonicalizeAll = putStrLn "Starting canonicalization workers (stub)"
