module Service.WorkflowEngine where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, readTVarIO, writeTVar, atomically)
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)
import Service.Workflow (Workflow)

-- | Workflow engine with full orchestration
data WorkflowEngine = WorkflowEngine
  { engineWorkflows :: TVar (Map.Map Text Workflow),
    engineInstances :: TVar (Map.Map Text WorkflowInstance),
    engineConfig :: WorkflowConfig
  }

-- | Workflow instance with execution state
data WorkflowInstance = WorkflowInstance
  { instanceId :: Text,
    instanceWorkflow :: Text,
    instanceState :: TVar InstanceState,
    instanceCreated :: UTCTime,
    instanceSteps :: [Text],
    instanceCurrentStep :: TVar Int
  }

-- | Instance execution states
data InstanceState
  = InstanceDraft
  | InstanceScheduled UTCTime
  | InstanceRunning { stepStartTime :: UTCTime }
  | InstanceCompleted UTCTime
  | InstanceFailed Text UTCTime
  | InstanceCancelled
  deriving (Show, Eq)

-- | Workflow configuration
data WorkflowConfig = WorkflowConfig
  { maxConcurrentInstances :: Int,
    defaultTimeoutSeconds :: Int,
    retryLimit :: Int
  }

-- | Initialize workflow engine
initWorkflowEngine :: WorkflowConfig -> IO WorkflowEngine
initWorkflowEngine config = do
  workflowsVar <- newTVarIO Map.empty
  instancesVar <- newTVarIO Map.empty
  return $ WorkflowEngine workflowsVar instancesVar config

-- | Create new workflow instance
createWorkflowInstance :: WorkflowEngine -> Text -> Text -> IO Text
createWorkflowInstance _ _workflowId _desc = do
  return (T.pack "stub-instance-id")

-- | Execute workflow step
executeWorkflowStep :: WorkflowEngine -> Text -> IO (Either Text ())
executeWorkflowStep engine instId = do
  mInstance <- atomically $ do
    insts <- readTVar (engineInstances engine)
    return $ Map.lookup instId insts

  case mInstance of
    Nothing -> return $ Left (T.pack "Instance not found")
    Just inst -> do
      state <- readTVarIO (instanceState inst)
      case state of
        InstanceDraft -> advanceStep engine inst
        InstanceScheduled _ -> advanceStep engine inst
        InstanceRunning _ -> return $ Left (T.pack "Already running")
        InstanceCompleted _ -> return $ Left (T.pack "Already completed")
        InstanceFailed _ _ -> return $ Left (T.pack "Failed, cannot advance")
        InstanceCancelled -> return $ Left (T.pack "Cancelled")

-- | Advance to next step
advanceStep :: WorkflowEngine -> WorkflowInstance -> IO (Either Text ())
advanceStep _ winst = do
  let steps = instanceSteps winst
  current <- readTVarIO (instanceCurrentStep winst)
  let totalSteps = length steps
  if current >= totalSteps
    then do
      now <- getCurrentTime
      atomically $ writeTVar (instanceState winst) (InstanceCompleted now)
      return $ Right ()
    else do
      atomically $ writeTVar (instanceCurrentStep winst) (current + 1)
      return $ Right ()

-- | Cancel workflow instance
cancelWorkflowInstance :: WorkflowEngine -> Text -> IO ()
cancelWorkflowInstance engine instId = atomically $ do
  insts <- readTVar (engineInstances engine)
  case Map.lookup instId insts of
    Just winst -> do
      writeTVar (instanceState winst) InstanceCancelled
      let insts' = Map.delete instId insts
      writeTVar (engineInstances engine) insts'
    Nothing -> return ()

-- | Get instance status
getInstanceStatus :: WorkflowEngine -> Text -> IO (Maybe InstanceState)
getInstanceStatus engine instId = atomically $ do
  insts <- readTVar (engineInstances engine)
  mInstance <- return $ Map.lookup instId insts
  case mInstance of
    Just winst -> Just <$> readTVar (instanceState winst)
    Nothing -> return Nothing

-- | List workflow instances
listWorkflowInstances :: WorkflowEngine -> IO [(Text, InstanceState)]
listWorkflowInstances engine = do
  insts <- readTVarIO (engineInstances engine)
  mapM (\(k, v) -> fmap (\s -> (k, s)) (readTVarIO (instanceState v))) (Map.toList insts)
