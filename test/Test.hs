-- | Main test suite for Surypus
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Test.Hspec
import qualified Finance.TaxSpec
import qualified Finance.AccountingSpec
import qualified Finance.BillSpec
import qualified Surypus.ValidationSpec
import qualified Core.PayrollSpec
import qualified Core.Accounting.CacheSpec
import qualified Core.Accounting.RedisCacheSpec
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
import qualified Domain.InvariantsSpec
import qualified Inventory.StockSpec
import qualified Inventory.WarehouseSpec
import qualified Inventory.GoodsSpec
import qualified Inventory.UnitSpec
import qualified Inventory.OperationsSpec
import qualified HR.OperationsSpec
import qualified Integration.API.ExternalAPISpec
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
import qualified TranscendenceSpec
import qualified AdditionalTests
import qualified DAL.TypesSpec
import qualified DAL.DBSpec
import qualified DAL.PoolSpec

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
  Core.Accounting.RedisCacheSpec.spec
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
  Integration.API.ExternalAPISpec.spec
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
  TranscendenceSpec.spec
  DAL.TypesSpec.spec
  DAL.DBSpec.spec
  DAL.PoolSpec.spec
  Domain.InvariantsSpec.spec
