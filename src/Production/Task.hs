-- | Task module - Tasks management
module Production.Task where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Task - Task/issue
data Task = Task
  { tskId :: Int64,
    tskTitle :: Text,
    tskDescription :: Text,
    tskAssigneeId :: Int64,
    tskStatus :: TaskStatus,
    tskPriority :: Priority,
    tskDueDate :: Maybe Day
  }
  deriving (Show, Eq)

data TaskStatus = TSOpen | TSInProgress | TSResolved | TSClosed
  deriving (Show, Eq)

data Priority = PLow | PMedium | PHigh | PCritical
  deriving (Show, Eq)
