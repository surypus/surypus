-- | Employee types - Staff management
module HR.Employee where

import Data.Int (Int64)
import Data.Maybe (isNothing)
import Data.Time (Day)

-- | Employee - Employee record
data Employee = Employee
  { empId :: Int64,
    empPersonId :: Int64, -- Link to Person
    empPostId :: Int64, -- Position ID
    empHireDate :: Day,
    empFireDate :: Maybe Day,
    empSalary :: Double,
    empFlags :: EmployeeFlags
  }
  deriving (Show, Eq)

-- | Employee flags
data EmployeeFlags = EmployeeFlags
  { efActive :: Bool, -- Currently employed
    efClockedIn :: Bool, -- Currently on shift
    efManager :: Bool, -- Has manager privileges
    efLocked :: Bool -- Account locked
  }
  deriving (Show, Eq)

-- | Employee status
data EmployeeStatus = ESActive | ESOnLeave | ESFired | ESRetired
  deriving (Show, Eq, Enum)

-- | Check if employee is active
isEmployeeActive :: Employee -> Bool
isEmployeeActive e = isNothing (empFireDate e)

-- | Get employee status based on dates
getEmployeeStatus :: Employee -> Day -> EmployeeStatus
getEmployeeStatus emp _today
  | isEmployeeActive emp = ESActive
  | otherwise = ESFired
