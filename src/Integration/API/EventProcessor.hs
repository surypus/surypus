module Integration.API.EventProcessor where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM (TQueue, TVar, isEmptyTQueue, newTQueueIO, readTQueue, writeTQueue, readTVar, atomically, newTVarIO, readTVarIO, writeTVar)
import Control.Monad (forever, when)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime)
import qualified Data.UUID as UUID
-- import Data.UUID (nextRandom)

-- | Event types
data EventType
  = SystemEvent
  | UserEvent
  | IntegrationEvent
  | ErrorEvent
  deriving (Show, Eq)

-- | Event payload
data Event = Event
  { eventId :: T.Text,
    eventType :: EventType,
    eventSource :: T.Text,
    eventData :: T.Text,
    eventTimestamp :: UTCTime
  }

-- | Event processor
data EventProcessor = EventProcessor
  { processorQueue :: TQueue Event,
    processorHandlers :: TVar [(EventType, Event -> IO ())],
    processorRunning :: TVar Bool
  }

-- | Initialize event processor
initEventProcessor :: IO EventProcessor
initEventProcessor = do
  queue <- newTQueueIO
  handlers <- newTVarIO []
  running <- newTVarIO True
  return $ EventProcessor queue handlers running

-- | Register event handler
registerHandler :: EventProcessor -> EventType -> (Event -> IO ()) -> IO ()
registerHandler processor eventType handler = atomically $ do
  handlers <- readTVar (processorHandlers processor)
  let updated = (eventType, handler) : handlers
  writeTVar (processorHandlers processor) updated

-- | Process events
processEvents :: EventProcessor -> IO ()
processEvents processor = forever $ do
  empty <- atomically $ isEmptyTQueue (processorQueue processor)
  when (not empty) $ do
    event <- atomically $ readTQueue (processorQueue processor)
    dispatchEvent processor event

-- | Dispatch to appropriate handler
dispatchEvent :: EventProcessor -> Event -> IO ()
dispatchEvent processor event = do
  handlers <- readTVarIO (processorHandlers processor)
  let matching = lookup (eventType event) handlers
  case matching of
    Just handler -> handler event
    Nothing -> return ()

-- | Publish event
publishEvent :: EventProcessor -> Event -> IO ()
publishEvent processor event = atomically $ do
  let queue = processorQueue processor
  writeTQueue queue event

-- | Generate event ID
generateEventId :: IO T.Text
generateEventId = do
  -- uuid <- UUID.nextRandom
  -- return $ T.pack $ UUID.toString uuid
  return (T.pack "event-id-placeholder")
