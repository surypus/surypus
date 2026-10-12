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
import qualified TestHelpers
import qualified System.RateLimiterSpec
import qualified System.CacheSpec
import qualified System.CounterSpec
import qualified System.SequenceSpec
import qualified JWTSpec
import qualified ConfigSpec
import qualified ObservabilitySpec
import qualified MigrationDryRunSpec
import qualified RBACCanonSpec
import qualified ConcurrencySpec
import qualified Phase5PropsSpec
import qualified QuickCheckInvariantsSpec
import qualified Inventory.StockSpec
import qualified Inventory.WarehouseSpec
import qualified Inventory.GoodsSpec
import qualified HR.OperationsSpec
import qualified Phase2Phase3.AccountingEventsSpec
import qualified Domain.ProductionPropertySpec
import qualified Contract.SchemaSpec
import DAL.Types

main :: IO ()
main = hspec $ do
  Finance.TaxSpec.spec
  Finance.AccountingSpec.spec
  Finance.BillSpec.spec
  Surypus.ValidationSpec.spec
  Core.PayrollSpec.spec
  TestHelpers.specBillLines
  TestHelpers.specPayroll
  TestHelpers.specProduction
  TestHelpers.specInventory
  System.RateLimiterSpec.spec
  System.CacheSpec.spec
  System.CounterSpec.spec
  System.SequenceSpec.spec
  JWTSpec.spec
  Core.Accounting.CacheSpec.spec
  ConfigSpec.spec
  ObservabilitySpec.spec
  MigrationDryRunSpec.spec
  RBACCanonSpec.spec
  ConcurrencySpec.spec
  Phase5PropsSpec.spec
  QuickCheckInvariantsSpec.spec
  Inventory.StockSpec.spec
  Inventory.WarehouseSpec.spec
  Inventory.GoodsSpec.spec
  HR.OperationsSpec.spec
  Phase2Phase3.AccountingEventsSpec.spec
  Domain.ProductionPropertySpec.spec
  Contract.SchemaSpec.spec

  describe "TestHelpers properties" $ do
    it "bill total equals sum of line totals" $
      property TestHelpers.prop_bill_post_total_equals_sum_of_lines
    it "salary amount is non-negative" $
      property TestHelpers.prop_salary_amount_nonnegative
    it "work order released never exceeds planned" $
      property TestHelpers.prop_work_order_released_le_planned
    it "bill line total is non-negative" $
      property TestHelpers.prop_bill_line_total_nonnegative

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
