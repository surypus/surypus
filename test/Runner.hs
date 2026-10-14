{-# LANGUAGE OverloadedStrings #-}
module Test.Runner where

import Test.Hspec

import qualified RBACCanonSpec as RBACCanon
import qualified MigrationDryRunSpec as MigrationDryRun
import qualified ObservabilitySpec as Observability
import qualified ConcurrencySpec as Concurrency
import qualified ConfigSpec as Config

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  RBACCanon.spec
  Observability.spec
  Concurrency.spec
  Config.spec
  MigrationDryRun.spec
