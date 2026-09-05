-- | Report module - Reporting engine
module Reports.Report  where

import Data.Int (Int64)
import Data.Text (Text)

-- | Report - Report template
data Report = Report
  { rptId :: Int64,
    rptCode :: Text,
    rptName :: Text,
    rptType :: ReportType,
    rptQuery :: Text, -- SQL or formula
    rptFlags :: Int
  }
  deriving (Show, Eq)

data ReportType = RTList | RTRegister | RTJournal | RTBalance | RTTax
  deriving (Show, Eq)

-- | ReportParam - Report parameter
data ReportParam = ReportParam
  { rpId :: Int64,
    rpReportId :: Int64,
    rpName :: Text,
    rpType :: ParamType,
    rpDefault :: Maybe Text
  }
  deriving (Show, Eq)

data ParamType = PTDate | PTDateRange | PTInt | PTText | PTObject
  deriving (Show, Eq)

-- | ReportOutput - Generated report
data ReportOutput = ReportOutput
  { roId :: Int64,
    roReportId :: Int64,
    roFormat :: OutputFormat,
    roPath :: Text,
    roSize :: Int64
  }
  deriving (Show, Eq)

data OutputFormat = OF_PDF | OF_XLSX | OF_HTML | OF_CSV
  deriving (Show, Eq)
