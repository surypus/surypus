-- | Position types - Job positions
module HR.Position where

import Data.Int (Int64)
import Data.Text (Text)

-- | Position - Job position
data Position = Position
  { posId :: Int64,
    posCode :: Text,
    posName :: Text,
    posParentId :: Maybe Int64, -- Parent position
    posFlags :: PositionFlags
  }
  deriving (Show, Eq)

-- | Position flags
data PositionFlags = PositionFlags
  { pfActive :: Bool, -- Active position
    pfSupervisor :: Bool, -- Supervisory role
    pfTemporary :: Bool -- Temporary position
  }
  deriving (Show, Eq)

-- | Staff list - Group of employees
data StaffList = StaffList
  { slId :: Int64,
    slCode :: Text,
    slName :: Text,
    slFlags :: Int
  }
  deriving (Show, Eq)

-- | Duty schedule - Work schedule
data DutySchedule = DutySchedule
  { dsId :: Int64,
    dsName :: Text,
    dsSchedule :: Text -- JSON schedule
  }
  deriving (Show, Eq)
