{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Event Store - PostgreSQL-backed event sourcing
module DAL.EventStore
   ( Event (..)
     , Snapshot (..)
     , Broadcaster
     , currentEventSchemaVersion
     , appendEvent
     , appendEventBroadcast
     , getEvents
     , getEventsFrom
     , replayAccount
     , getLatestSequence
     , saveSnapshot
     , getLatestSnapshot
     , replayFromSnapshot
     , upgradeEvent
     , newBroadcaster
     , subscribe
     , unsubscribe
   )
   where

import Control.Concurrent.STM
import Control.Monad (foldM)
import DAL.Database (ConnectionPool, runDb)
import Data.Aeson (Value(..), encode, decode, object, String(..))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, getCurrentTime)
import Database.Persist.Sql (rawSql, rawExecute, Single(..), PersistValue(..))
import GHC.Generics (Generic)

currentEventSchemaVersion :: Int
currentEventSchemaVersion = 1

data Event = Event
  { eventAggregateId      :: Int64
  , eventAggregateType    :: Text
  , eventEventType        :: Text
  , eventEventVersion     :: Int
  , eventSchemaVersion    :: Int
  , eventEventData        :: Value
  , eventEventMetadata    :: Maybe Value
  , eventSequenceNumber   :: Int64
  , eventOccurredAt       :: UTCTime
  , eventCreatedAt        :: UTCTime
  }
  deriving (Show, Generic)

data Snapshot = Snapshot
  { snapAggregateId   :: Int64
  , snapAggregateType :: Text
  , snapVersion       :: Int
  , snapLastSeq       :: Int64
  , snapData          :: Text
  , snapCreatedAt     :: UTCTime
  }
  deriving (Show, Generic)

data Broadcaster = Broadcaster
  { bcSubscribers :: TVar (Map Int BroadcastCallback)
  , bcNextId      :: TVar Int
  }

type BroadcastCallback = Event -> IO ()

-- | Create a new broadcaster
newBroadcaster :: IO Broadcaster
newBroadcaster = do
  subs <- newTVarIO M.empty
  nextId <- newTVarIO 0
  return $ Broadcaster subs nextId

-- | Subscribe to events
subscribe :: Broadcaster -> BroadcastCallback -> IO Int
subscribe broadcaster callback = do
  sid <- readTVarIO (bcNextId broadcaster)
  modifyTVar' (bcSubscribers broadcaster) $ M.insert sid callback
  modifyTVar' (bcNextId broadcaster) (+1)
  return sid

-- | Unsubscribe from events
unsubscribe :: Broadcaster -> Int -> IO ()
unsubscribe broadcaster sid = do
  modifyTVar' (bcSubscribers broadcaster) $ M.delete sid

-- | Append an event to the event store
appendEvent :: ConnectionPool -> Event -> IO (Either Text ())
appendEvent pool event = do
  now <- getCurrentTime
  let sql = "INSERT INTO event_store (\
            \  aggregate_id, aggregate_type, event_type, event_version, \
            \  event_schema_version, event_data, event_metadata, \
            \  sequence_number, occurred_at, created_at) \
            \VALUES (?, ?, ?, ?, ?, ?::jsonb, ?::jsonb, ?, ?, ?)"
  result <- runDb pool $ rawExecute sql
    [ PersistInt64 (eventAggregateId event)
    , PersistText (eventAggregateType event)
    , PersistText (eventEventType event)
    , PersistInt64 (fromIntegral $ eventEventVersion event)
    , PersistInt64 (fromIntegral $ eventSchemaVersion event)
    , PersistText (T.pack $ show $ eventEventData event)
    , maybe PersistNull (PersistText . T.pack . show) (eventEventMetadata event)
    , PersistInt64 (eventSequenceNumber event)
    , PersistUTCTime (eventOccurredAt event)
    , PersistUTCTime now
    ]
  return $ Right ()

-- | Append event and broadcast to subscribers
appendEventBroadcast :: Broadcaster -> ConnectionPool -> Event -> IO (Either Text ())
appendEventBroadcast broadcaster pool event = do
  result <- appendEvent pool event
  case result of
    Right () -> do
      subs <- readTVarIO (bcSubscribers broadcaster)
      mapM_ (\cb -> cb event) (M.elems subs)
      return $ Right ()
    Left err -> return $ Left err

-- | Get events for an aggregate
getEvents :: ConnectionPool -> Int64 -> Text -> IO (Either Text [Event])
getEvents pool aggId aggType = do
  let sql = "SELECT aggregate_id, aggregate_type, event_type, event_version, \
            \  event_schema_version, event_data, event_metadata, \
            \  sequence_number, occurred_at, created_at \
            \FROM event_store WHERE aggregate_id = ? AND aggregate_type = ? \
            \ORDER BY sequence_number ASC"
  rows <- runDb pool $ rawSql sql [PersistInt64 aggId, PersistText aggType]
  return $ Right $ map parseEvent rows

-- | Get events from a specific sequence number
getEventsFrom :: ConnectionPool -> Int64 -> Text -> Int64 -> IO (Either Text [Event])
getEventsFrom pool aggId aggType fromSeq = do
  let sql = "SELECT aggregate_id, aggregate_type, event_type, event_version, \
            \  event_schema_version, event_data, event_metadata, \
            \  sequence_number, occurred_at, created_at \
            \FROM event_store WHERE aggregate_id = ? AND aggregate_type = ? \
            \  AND sequence_number >= ? \
            \ORDER BY sequence_number ASC"
  rows <- runDb pool $ rawSql sql [PersistInt64 aggId, PersistText aggType, PersistInt64 fromSeq]
  return $ Right $ map parseEvent rows

-- | Replay events for an aggregate
replayAccount :: ConnectionPool -> Int64 -> Text -> IO (Either Text [Event])
replayAccount pool aggId aggType = getEvents pool aggId aggType

-- | Get latest sequence number for an aggregate
getLatestSequence :: ConnectionPool -> Int64 -> Text -> IO (Either Text (Maybe Int64))
getLatestSequence pool aggId aggType = do
  let sql = "SELECT MAX(sequence_number) FROM event_store WHERE aggregate_id = ? AND aggregate_type = ?"
  rows <- runDb pool $ rawSql sql [PersistInt64 aggId, PersistText aggType]
  case rows of
    (Single (PersistInt64 n) : _) -> return $ Right $ Just n
    (Single PersistNull : _) -> return $ Right Nothing
    _ -> return $ Right Nothing

-- | Save a snapshot
saveSnapshot :: ConnectionPool -> Snapshot -> IO (Either Text ())
saveSnapshot pool snap = do
  let sql = "INSERT INTO event_snapshots (\
            \  aggregate_id, aggregate_type, version, last_seq, snapshot_data, created_at) \
            \VALUES (?, ?, ?, ?, ?, ?) \
            \ON CONFLICT (aggregate_id, aggregate_type, version) DO UPDATE SET \
            \  last_seq = EXCLUDED.last_seq, snapshot_data = EXCLUDED.snapshot_data, created_at = EXCLUDED.created_at"
  result <- runDb pool $ rawExecute sql
    [ PersistInt64 (snapAggregateId snap)
    , PersistText (snapAggregateType snap)
    , PersistInt64 (fromIntegral $ snapVersion snap)
    , PersistInt64 (snapLastSeq snap)
    , PersistText (snapData snap)
    , PersistUTCTime (snapCreatedAt snap)
    ]
  return $ Right ()

-- | Get latest snapshot for an aggregate
getLatestSnapshot :: ConnectionPool -> Int64 -> Text -> IO (Either Text (Maybe Snapshot))
getLatestSnapshot pool aggId aggType = do
  let sql = "SELECT aggregate_id, aggregate_type, version, last_seq, snapshot_data, created_at \
            \FROM event_snapshots WHERE aggregate_id = ? AND aggregate_type = ? \
            \ORDER BY version DESC LIMIT 1"
  rows <- runDb pool $ rawSql sql [PersistInt64 aggId, PersistText aggType]
  case rows of
    (Single id' : Single typ : Single ver : Single lastSeq : Single data' : Single createdAt : _) -> do
      mSnap <- parseSnapshot (T.pack $ show id') (T.pack $ show typ) (T.pack $ show ver) (T.pack $ show lastSeq) (T.pack $ show data') (T.pack $ show createdAt)
      return $ Right mSnap
    _ -> return $ Right Nothing

-- | Replay from snapshot
replayFromSnapshot :: ConnectionPool -> Int64 -> Text -> IO (Either Text [Event])
replayFromSnapshot pool aggId aggType = do
  mSnap <- getLatestSnapshot pool aggId aggType
  case mSnap of
    Right (Just snap) -> getEventsFrom pool aggId aggType (snapLastSeq snap + 1)
    Right Nothing -> getEvents pool aggId aggType
    Left err -> return $ Left err

-- | Upgrade event to new schema version
upgradeEvent :: Event -> Int -> Event
upgradeEvent event newVersion = event { eventSchemaVersion = newVersion }

-- | Parse event from database row
parseEvent :: [PersistValue] -> Event
parseEvent (Single id' : Single typ : Single evType : Single evVer : Single evSchemaVer : Single evData : Single evMeta : Single seqNum : Single occurredAt : Single createdAt : _) =
  Event
    { eventAggregateId = read $ T.unpack $ T.pack $ show id'
    , eventAggregateType = T.pack $ show typ
    , eventEventType = T.pack $ show evType
    , eventEventVersion = read $ T.unpack $ T.pack $ show evVer
    , eventSchemaVersion = read $ T.unpack $ T.pack $ show evSchemaVer
    , eventEventData = object ["raw" .= T.pack (show evData)]
    , eventEventMetadata = if T.null (T.pack $ show evMeta) then Nothing else Just $ object ["raw" .= T.pack (show evMeta)]
    , eventSequenceNumber = read $ T.unpack $ T.pack $ show seqNum
    , eventOccurredAt = read $ T.unpack $ T.pack $ show occurredAt
    , eventCreatedAt = read $ T.unpack $ T.pack $ show createdAt
    }
parseEvent _ = Event 0 "" "" 0 0 (object []) Nothing 0 (read "1970-01-01 00:00:00 UTC") (read "1970-01-01 00:00:00 UTC")

-- | Parse snapshot from text fields
parseSnapshot :: Text -> Text -> Text -> Text -> Text -> Text -> IO (Maybe Snapshot)
parseSnapshot id' typ ver lastSeq data' createdAt = do
  mId <- readMaybe (T.unpack id')
  mVer <- readMaybe (T.unpack ver)
  mLastSeq <- readMaybe (T.unpack lastSeq)
  mCreatedAt <- readMaybe (T.unpack createdAt)
  return $ Snapshot mId (T.unpack typ) mVer mLastSeq (T.pack $ T.unpack data') mCreatedAt

-- | Safe readMaybe
readMaybe :: Read a => String -> Maybe a
readMaybe s = case reads s of
  [(x, "")] -> Just x
  _ -> Nothing

-- | Helper for JSON object construction
object :: [Text] -> Value
object pairs = Data.Aeson.object $ map (\t -> ("field", Data.Aeson.String t)) pairs
