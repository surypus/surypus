module Integration.API.EventStore where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar, readTVarIO)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import qualified Data.UUID as UUID

-- | Event store configuration
data EventStoreConfig = EventStoreConfig
  { maxEventSize :: Int,
    eventRetentionDays :: Int,
    snapshotInterval :: Int
  }

-- | Event data
data Event = Event
  { eventId :: Text,
    eventType :: Text,
    eventData :: Text,
    eventVersion :: Int,
    eventTimestamp :: UTCTime,
    eventMetadata :: Map.Map Text Text
  }

-- | Stream position
data StreamPosition = StreamPosition
  { streamName :: Text,
    streamVersion :: Int
  }

-- | Event store
data EventStore = EventStore
  { storeEvents :: TVar (Map.Map Text [Event]),
    storeSnapshots :: TVar (Map.Map Text (Event, [Event])),
    storeConfig :: EventStoreConfig
  }

-- | Initialize event store
initEventStore :: EventStoreConfig -> IO EventStore
initEventStore config = do
  eventsVar <- newTVarIO Map.empty
  snapshotsVar <- newTVarIO Map.empty
  return $ EventStore eventsVar snapshotsVar config

-- | Append event to stream
appendEvent :: EventStore -> Text -> Event -> IO ()
appendEvent store stream event = atomically $ do
  streams <- readTVar (storeEvents store)
  let updated = Map.insertWith (++) stream [event] streams
  writeTVar (storeEvents store) updated

-- | Read events from stream
readStream :: EventStore -> Text -> IO [Event]
readStream store stream = do
  events <- readTVarIO (storeEvents store)
  return $ Map.findWithDefault [] stream events

-- | Create snapshot
createSnapshot :: EventStore -> Text -> IO ()
createSnapshot store stream = do
  events <- readTVarIO (storeEvents store)
  case Map.lookup stream events of
    Just [] -> return ()
    Just [e] -> atomically $ do
      snaps <- readTVar (storeSnapshots store)
      let snapshot = (e, [])
      writeTVar (storeSnapshots store) (Map.insert stream snapshot snaps)
    Just (e:rest) -> atomically $ do
      snaps <- readTVar (storeSnapshots store)
      let snapshot = (last (e:rest), e:rest)
      writeTVar (storeSnapshots store) (Map.insert stream snapshot snaps)
    Nothing -> return ()

-- | Load snapshot
loadSnapshot :: EventStore -> Text -> IO (Maybe (Event, [Event]))
loadSnapshot store stream = do
  snaps <- readTVarIO (storeSnapshots store)
  return $ Map.lookup stream snaps

-- | Subscribe to events
subscribeToStream :: EventStore -> Text -> IO [Event]
subscribeToStream store stream = readStream store stream

-- | Get stream head
goToStreamHead :: EventStore -> Text -> IO StreamPosition
goToStreamHead store stream = do
  events <- readTVarIO (storeEvents store)
  let es = Map.findWithDefault [] stream events
  return $ StreamPosition stream (length es)
