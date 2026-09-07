-- | Workflow module - Business process automation
module Service.Workflow where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Workflow - Business process
data Workflow = Workflow
  { wfId :: Int64,
    wfName :: Text,
    wfObjectType :: Int64,
    wfDefinition :: Text, -- JSON state machine
    wfFlags :: Int
  }
  deriving (Show, Eq)

-- | WorkflowInstance - Active process
data WorkflowInstance = WorkflowInstance
  { wfiId :: Int64,
    wfiWorkflowId :: Int64,
    wfiObjectId :: Int64,
    wfiState :: Text,
    wfiStarted :: Day,
    wfiFinished :: Maybe Day
  }
  deriving (Show, Eq)

-- | WorkflowTransition - State transition
data WorkflowTransition = WorkflowTransition
  { wftId :: Int64,
    wftInstanceId :: Int64,
    wftFromState :: Text,
    wftToState :: Text,
    wftUserId :: Int64,
    wftDate :: Day,
    wftComment :: Text
  }
  deriving (Show, Eq)
