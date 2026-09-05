-- | Visit module - Client visits
module Commerce.Visits.Visit  where

import Data.Int (Int64)
import Data.Time (Day)

-- | Visit - Client visit
data Visit = Visit
  { vsId :: Int64,
    vsDate :: Day,
    vsClientId :: Int64,
    vsEmployeeId :: Int64,
    vsPurpose :: String,
    vsResult :: String
  }
  deriving (Show, Eq)

-- | Is completed
isVisitCompleted :: Visit -> Bool
isVisitCompleted v = not (null (vsResult v))
