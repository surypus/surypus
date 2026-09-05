-- | Goal module - Goals
module HR.Goals.Goal where

import Data.Int (Int64)
import Data.Time (Day)

-- | Goal - Sales goal
data Goal = Goal
  { glId :: Int64,
    glEmployeeId :: Int64,
    glPeriodStart :: Day,
    glPeriodEnd :: Day,
    glTarget :: Double,
    glActual :: Double
  }
  deriving (Show, Eq)

-- | Get completion percent
getCompletion :: Goal -> Double
getCompletion g = (glActual g / glTarget g) * 100
