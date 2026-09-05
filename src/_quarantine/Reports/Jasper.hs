-- | Reports Module - Jasper/Pentaho integration
module Reports.Jasper where

import Data.Int (Int64)
import Data.Time (Day, fromGregorian)

-- | Report template
data ReportTemplate = ReportTemplate
  { rtId :: Int64,
    rtCode :: String,
    rtName :: String,
    rtType :: ReportType,
    rtJasperFile :: Maybe String
  }
  deriving (Show, Eq)

-- | Report types
data ReportType = RTSales | RTInventory | RTFinancial | RTTax | RTCustom
  deriving (Show, Eq)

-- | Report parameters
data ReportParams = ReportParams
  { rpDateFrom :: Day,
    rpDateTo :: Day
  }
  deriving (Show, Eq)

-- | Report status
data ReportStatus = RSPending | RSProcessing | RSCompleted | RSFailed
  deriving (Show, Eq)

-- | Report job
data ReportJob = ReportJob
  { rjId :: Int64,
    rjTemplateId :: Int64,
    rjStatus :: ReportStatus,
    rjOutputPath :: Maybe String,
    rjCreatedAt :: Day
  }
  deriving (Show, Eq)

-- | Available report templates
getReportTemplates :: [ReportTemplate]
getReportTemplates =
  [ ReportTemplate 1 "sales_daily" "Daily Sales" RTSales (Just "sales_daily.jrxml"),
    ReportTemplate 2 "inventory" "Inventory Report" RTInventory (Just "inventory.jrxml"),
    ReportTemplate 3 "balance_sheet" "Balance Sheet" RTFinancial (Just "balance_sheet.jrxml")
  ]

-- | Create report job
createReportJob :: Int64 -> ReportJob
createReportJob tid =
  ReportJob
    { rjId = 0,
      rjTemplateId = tid,
      rjStatus = RSPending,
      rjOutputPath = Nothing,
      rjCreatedAt = fromGregorian 2026 3 9
    }
