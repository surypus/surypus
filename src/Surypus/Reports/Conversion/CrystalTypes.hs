-- | Crystal Reports types
module Surypus.Reports.Conversion.CrystalTypes where

import Data.Text (Text)

data CrystalReport = CrystalReport
  { crName :: Text,
    crSections :: [CrystalSection],
    crGroups :: [Text],
    crParameters :: [Text],
    crDatabaseFields :: [Text],
    crFormulaFields :: [Text],
    crSubreports :: [CrystalSubreport]
  }
  deriving (Show, Eq)

data CrystalSection
  = ReportHeaderSection [Text]
  | PageHeaderSection [Text]
  | DetailsSection [Text]
  | PageFooterSection [Text]
  | ReportFooterSection [Text]
  deriving (Show, Eq)

data CrystalSubreport = CrystalSubreport
  { csName :: Text,
    csReport :: CrystalReport
  }
  deriving (Show, Eq)