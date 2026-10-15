-- | Main test suite for Surypus
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Test.Hspec
import Test.QuickCheck
import qualified Data.Aeson as A
import Data.Time.Calendar (fromGregorian)
import qualified Finance.TaxSpec
import qualified Finance.AccountingSpec
import qualified Finance.BillSpec
import qualified Surypus.ValidationSpec
import qualified Core.PayrollSpec
import qualified Core.Accounting.CacheSpec
import qualified System.RateLimiterSpec
import qualified System.CacheSpec
import qualified System.CircuitBreakerSpec
import qualified System.CounterSpec
import qualified System.MetricsCollectorSpec
import qualified System.SequenceSpec
import qualified System.RetrySpec
import qualified JWTSpec
import qualified ConfigSpec
import qualified ObservabilitySpec
import qualified MigrationDryRunSpec
import qualified RBACCanonSpec
import qualified Surypus.RBAC.StoreSpec
import qualified ConcurrencySpec
import qualified QuickCheckInvariantsSpec
import qualified Inventory.StockSpec
import qualified Inventory.WarehouseSpec
import qualified Inventory.GoodsSpec
import qualified Inventory.UnitSpec
import qualified Inventory.OperationsSpec
import qualified HR.OperationsSpec
import qualified Service.WorkflowEngineSpec
import qualified Phase2Phase3.AccountingEventsSpec
import qualified Phase2Phase3.AccountingReadModelSpec
import qualified Core.Accounting.ReadModelSpec
import qualified Core.TaxSpec
import qualified Core.OptimizationSpec
import qualified Contract.SchemaSpec
import qualified Commerce.PriceSpec
import qualified Commerce.CashSessionTempSpec
import qualified EmailSpec
import qualified System.ValidationSpec
import qualified AdditionalTests
import DAL.Types

main :: IO ()
main = hspec $ do
  Finance.TaxSpec.spec
  Finance.AccountingSpec.spec
  Finance.BillSpec.spec
  Surypus.ValidationSpec.spec
  Core.PayrollSpec.spec
  System.RateLimiterSpec.spec
  System.CacheSpec.spec
  System.CircuitBreakerSpec.spec
  System.CounterSpec.spec
  System.MetricsCollectorSpec.spec
  System.SequenceSpec.spec
  System.RetrySpec.spec
  JWTSpec.spec
  Core.Accounting.CacheSpec.spec
  ConfigSpec.spec
  ObservabilitySpec.spec
  MigrationDryRunSpec.spec
  RBACCanonSpec.spec
  Surypus.RBAC.StoreSpec.spec
  ConcurrencySpec.spec
  QuickCheckInvariantsSpec.spec
  Inventory.StockSpec.spec
  Inventory.WarehouseSpec.spec
  Inventory.GoodsSpec.spec
  Inventory.OperationsSpec.spec
  Inventory.UnitSpec.spec
  HR.OperationsSpec.spec
  Service.WorkflowEngineSpec.spec
  Phase2Phase3.AccountingEventsSpec.spec
  Phase2Phase3.AccountingReadModelSpec.spec
  Core.Accounting.ReadModelSpec.spec
  Core.TaxSpec.spec
  Core.OptimizationSpec.spec
  Contract.SchemaSpec.spec
  Commerce.PriceSpec.spec
  Commerce.CashSessionTempSpec.spec
  EmailSpec.spec
  System.ValidationSpec.spec
  AdditionalTests.spec

  describe "DAL.Types JSON roundtrip" $ do
    it "Person roundtrip" $ do
      let p = Person 1 (Just "001") "Test" (Just "7707083893") (Just "770701001") (Just 1) (Just 1)
      A.decode (A.encode p) `shouldBe` Just p

    it "Goods roundtrip" $ do
      let g = Goods 1 (Just "001") "Test" Nothing (Just "123456") (Just 1) Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing
      A.decode (A.encode g) `shouldBe` Just g

    it "Bill roundtrip" $ do
      let b = Bill 1 (Just "B-001") (Just "sale") (Just "paid") (fromGregorian 2024 1 1) (Just 1) (Just 1) 1000.0 0.0 200.0
      A.decode (A.encode b) `shouldBe` Just b

    it "TaxEntity roundtrip" $ do
      let t = TaxEntity "tax-1" "VAT" "Value Added Tax" "20"
      A.decode (A.encode t) `shouldBe` Just t

    it "Pagination roundtrip" $ do
      let p = Pagination 0 10
      A.decode (A.encode p) `shouldBe` Just p

    it "AccTurnInput roundtrip" $ do
      let input = AccTurnInput 1 2 100.0 (Just "Test")
      A.decode (A.encode input) `shouldBe` Just input

    it "MutationResult roundtrip" $ do
      let mr = MutationResult True (Just 42) "Success"
      A.decode (A.encode mr) `shouldBe` Just mr

  describe "Sanity" $ do
    it "True is True" $ do
      True `shouldBe` True
