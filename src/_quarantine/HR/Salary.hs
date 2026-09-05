-- | Salary module - Salary calculation
module HR.Salary where

import Data.Int (Int64)
import Data.Time (Day)

-- | Salary - Salary calculation
data Salary = Salary
  { salId :: Int64,
    salEmployeeId :: Int64,
    salPeriod :: Day,
    salBase :: Double,
    salBonus :: Double,
    salTax :: Double,
    salNet :: Double
  }
  deriving (Show, Eq)

-- | SalaryItem - Salary component
data SalaryItem = SalaryItem
  { siId :: Int64,
    siSalaryId :: Int64,
    siType :: SalaryItemType,
    siAmount :: Double
  }
  deriving (Show, Eq)

data SalaryItemType = SITBase | SITBonus | SITPenalty | SITTax | SITAdvance
  deriving (Show, Eq)
