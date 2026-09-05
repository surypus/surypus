-- | Return module - Returns
module Commerce.Return  where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Return - Return record
data Return = Return
  { retId :: Int64,
    retCode :: Text,
    retDate :: Day,
    retOrderId :: Int64,
    retReason :: Text,
    retStatus :: ReturnStatus
  }
  deriving (Show, Eq)

data ReturnStatus = RSPending | RSApproved | RSRejected | RSCompleted
  deriving (Show, Eq)

-- | Is pure completed
isReturnCompleted :: Return -> Bool
isReturnCompleted r = retStatus r == RSCompleted
