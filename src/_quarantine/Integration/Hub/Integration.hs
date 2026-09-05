module Integration.Hub.Integration where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar, readTVarIO)
import Control.Exception (SomeException, try)
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time.Clock (UTCTime, getCurrentTime)

type Text = T.Text

-- | Integration context for connecting all systems
data IntegrationContext = IntegrationContext
  { contextLogger :: TVar [(UTCTime, Text)],
    contextCache :: TVar (Map.Map Text Text),
    contextQueue :: TVar [Text],
    contextMetrics :: TVar (Map.Map Text Double)
  }

-- | Initialize integration context
initIntegrationContext :: IO IntegrationContext
initIntegrationContext = do
  loggerVar <- newTVarIO []
  cacheVar <- newTVarIO Map.empty
  queueVar <- newTVarIO []
  metricsVar <- newTVarIO Map.empty
  return
    IntegrationContext
      { contextLogger = loggerVar,
        contextCache = cacheVar,
        contextQueue = queueVar,
        contextMetrics = metricsVar
      }

-- | Log integration event
logIntegrationEvent :: IntegrationContext -> Text -> Text -> IO ()
logIntegrationEvent context event metadata = do
  now <- getCurrentTime
  atomically $ do
    logs <- readTVar (contextLogger context)
    let newLog = (now, T.append event (T.append (T.pack ": ") metadata))
    writeTVar (contextLogger context) (newLog : logs)

-- | Shared cache for integrations
shareCache :: IntegrationContext -> Text -> Text -> IO ()
shareCache context key value = atomically $ do
  cache <- readTVar (contextCache context)
  writeTVar (contextCache context) (Map.insert key value cache)

-- | Get shared cache value
getSharedCache :: IntegrationContext -> Text -> IO (Maybe Text)
getSharedCache context key = atomically $ do
  cache <- readTVar (contextCache context)
  return $ Map.lookup key cache

-- | Queue for cross-system communication
queueMessage :: IntegrationContext -> Text -> IO ()
queueMessage context msg = atomically $ do
  q <- readTVar (contextQueue context)
  writeTVar (contextQueue context) (q ++ [msg])

-- | Metrics aggregation
recordMetric :: IntegrationContext -> Text -> Double -> IO ()
recordMetric context name value = atomically $ do
  metrics <- readTVar (contextMetrics context)
  writeTVar (contextMetrics context) (Map.insert name value metrics)

-- | Aggregate metrics from all systems
aggregateMetrics :: IntegrationContext -> IO (Map.Map Text Double)
aggregateMetrics context = readTVarIO (contextMetrics context)

-- | Transaction coordinator for distributed operations
data Transaction = Transaction
  { transactionId :: Text,
    operations :: [IO ()],
    status :: TVar TransactionStatus
  }

data TransactionStatus
  = Active
  | Committed
  | RolledBack
  deriving (Show, Eq)

-- | Execute transaction
executeTransaction :: Transaction -> IO (Either Text ())
executeTransaction txn = do
  results <- mapM (\op -> try op :: IO (Either SomeException ())) (operations txn)
  if all (either (const False) (const True)) results
    then do
      atomically $ writeTVar (status txn) Committed
      return $ Right ()
    else do
      atomically $ writeTVar (status txn) RolledBack
      return $ Left (T.pack "Transaction failed")
