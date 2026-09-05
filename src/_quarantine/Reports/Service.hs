module Reports.Service
  ( ReportService   (..),
    createReportService,
    generateSalesReport,
    generateInventoryReport,
    generateFinancialReport,
    generatePayrollSummary,
    generateTaxReport,
    SalesReport   (..),
    InventoryReport   (..),
    FinancialReport   (..),
    PayrollSummary   (..),
    TaxReport   (..)
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
-- | Stub type for Pool
type Pool = ()

data ReportService = ReportService
  { rsPool :: Pool
  }

createReportService :: Pool -> ReportService
createReportService = ReportService

data SalesReport = SalesReport
  { salesBillCount :: Int,
    salesTotalAmount :: Double,
    salesTotalTax :: Double
  }

data InventoryReport = InventoryReport
  { inventoryItemCount :: Int,
    inventoryTotalQuantity :: Double
  }

data FinancialReport = FinancialReport
  { financialTotalDebit :: Double,
    financialTotalCredit :: Double
  }

data PayrollSummary = PayrollSummary
  { summaryEmployeeCount :: Int,
    summaryTotalPaid :: Double
  }

data TaxReport = TaxReport
  { taxTotalVAT :: Double,
    taxCount :: Int
  }

generateSalesReport :: ReportService -> Day -> Day -> IO (Either Text SalesReport)
generateSalesReport _ _ _ = pure $ Right (SalesReport 0 0 0)

generateInventoryReport :: ReportService -> Maybe Int64 -> IO (Either Text InventoryReport)
generateInventoryReport _ _ = pure $ Right (InventoryReport 0 0)

generateFinancialReport :: ReportService -> Day -> Day -> IO (Either Text FinancialReport)
generateFinancialReport _ _ _ = pure $ Right (FinancialReport 0 0)

generatePayrollSummary :: ReportService -> Day -> Day -> IO (Either Text PayrollSummary)
generatePayrollSummary _ _ _ = pure $ Right (PayrollSummary 0 0)

generateTaxReport :: ReportService -> Day -> Day -> IO (Either Text TaxReport)
generateTaxReport _ _ _ = pure $ Right (TaxReport 0 0)
