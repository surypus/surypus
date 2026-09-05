-- | Activity module - Activities
module HR.Activity where

import Data.Int (Int64)
import Data.Time (Day)

-- | Activity - Activity log
data Activity = Activity
  { actId :: Int64,
    actDate :: Day,
    actUserId :: Int64,
    actAction :: String,
    actEntityType :: String,
    actEntityId :: Int64
  }
  deriving (Show, Eq)

-- | Get action
getAction :: Activity -> String
getAction = actAction
