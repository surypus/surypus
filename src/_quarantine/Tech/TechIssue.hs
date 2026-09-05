-- | TechIssue module - Tech issues
module Tech.TechIssue where

import Data.Int (Int64)
import Data.Time (Day)

-- | TechIssue - Tech issue (списание)
data TechIssue = TechIssue
  { tiId :: Int64,
    tiCode :: String,
    tiDate :: Day,
    tiProductId :: Int64,
    tiOutputQty :: Double,
    tiReason :: String
  }
  deriving (Show, Eq)

-- | Get quantity
getIssueQty :: TechIssue -> Double
getIssueQty = tiOutputQty
