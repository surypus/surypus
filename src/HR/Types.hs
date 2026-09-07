{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | HR / Payroll core types (Phase 1: stub)
module HR.Types
  ( SalaryCharge(..)
  , SalaryRecord(..)
  , SalarySummary(..)
  , SalaryChargeInput(..)
  , calcPeriodDays
  , calcSalaryPerDay
  , validateSalaryRecord
  , validateSalaryChargeInput
  , mkSalarySummary
  , mkSalaryCharge
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)

-- | Salary charge
data SalaryCharge = SalaryCharge
  { salaryChargeId :: !Int64
  , salaryChargeAmount :: !Double
  } deriving (Show, Eq, Generic)

instance FromJSON SalaryCharge
instance ToJSON SalaryCharge

-- | Salary record
data SalaryRecord = SalaryRecord
  { salaryRecordId :: !Int64
  , salaryRecordAmount :: !Double
  } deriving (Show, Eq, Generic)

instance FromJSON SalaryRecord
instance ToJSON SalaryRecord

-- | Salary summary
data SalarySummary = SalarySummary
  { salarySummaryTotal :: !Double
  , salarySummaryCount :: !Int
  } deriving (Show, Eq, Generic)

instance FromJSON SalarySummary
instance ToJSON SalarySummary

-- | Salary charge input
data SalaryChargeInput = SalaryChargeInput
  { salaryChargeInputAmount :: !Double
  } deriving (Show, Eq, Generic)

instance FromJSON SalaryChargeInput
instance ToJSON SalaryChargeInput

-- | Calculate period days (stub)
calcPeriodDays :: Int64 -> Int64 -> Int64
calcPeriodDays _ _ = 30

-- | Calculate salary per day (stub)
calcSalaryPerDay :: Double -> Int64 -> Double
calcSalaryPerDay amount days = if days > 0 then amount / fromIntegral days else 0

-- | Validate salary record (stub)
validateSalaryRecord :: SalaryRecord -> Bool
validateSalaryRecord _ = True

-- | Validate salary charge input (stub)
validateSalaryChargeInput :: SalaryChargeInput -> Bool
validateSalaryChargeInput _ = True

-- | Make salary summary (stub)
mkSalarySummary :: [SalaryCharge] -> SalarySummary
mkSalarySummary charges = SalarySummary
  { salarySummaryTotal = sum (map salaryChargeAmount charges)
  , salarySummaryCount = length charges
  }

-- | Make salary charge (stub)
mkSalaryCharge :: Double -> Int64 -> SalaryCharge
mkSalaryCharge amt id = SalaryCharge
  { salaryChargeId = id
  , salaryChargeAmount = amt
  }
