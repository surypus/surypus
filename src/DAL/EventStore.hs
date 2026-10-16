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
   ) where

import Control.Concurrent.STM
import DAL.Database (ConnectionPool, runDb)
import Data.Aeson (Value (..), decodeStrict, encode)
import qualified Data.ByteString.Lazy as LBS
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, getCurrentTime)
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Database.Persist.Sql (PersistValue (..), Single (..), rawExecute, rawSql)
import GHC.Generics (Generic)

-- | Extract Int64 from PersistValue
persistToInt64 :: PersistValue -> Int64
persistToInt64 (PersistInt64 n) = n
persistToInt64 (PersistDouble n) = round n
persistToInt64 (PersistText t) = fromMaybe 0 (readMaybe (T.unpack t))
persistToInt64 _ = 0

-- | Extract Text from PersistValue
--
-- PostgreSQL hands @jsonb@/@json@ columns back as 'PersistByteString', so they
-- have to be decoded rather than dropped.
persistToText :: PersistValue -> Text
persistToText (PersistText t) = t
persistToText (PersistByteString bs) = TE.decodeUtf8 bs
persistToText (PersistInt64 n) = T.pack $ show n
persistToText (PersistDouble n) = T.pack $ show n
persistToText (PersistUTCTime t) = T.pack $ show t
persistToText _ = ""

-- | Extract a timestamp from a PersistValue
persistToTime :: PersistValue -> UTCTime
persistToTime (PersistUTCTime t) = t
persistToTime (PersistText t) =
  fromMaybe epoch $ parseTimeM True defaultTimeLocale "%Y-%m-%d %H:%M:%S%Q%Z" (T.unpack t)
persistToTime _ = epoch

-- | Decode a JSON payload, falling back to 'Null' for anything malformed
decodeJSON :: Text -> Value
decodeJSON t = fromMaybe Null (decodeStrict (TE.encodeUtf8 t))

epoch :: UTCTime
epoch = read "1970-01-01 00:00:00 UTC"

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
  deriving (Show, Eq, Generic)

data Snapshot = Snapshot
  { snapAggregateId   :: Int64
  , snapAggregateType :: Text
  , snapVersion       :: Int
  , snapLastSeq       :: Int64
  , snapData          :: Text
  , snapCreatedAt     :: UTCTime
  }
  deriving (Show, Eq, Generic)

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
  atomically $ modifyTVar' (bcSubscribers broadcaster) $ M.insert sid callback
  atomically $ modifyTVar' (bcNextId broadcaster) (+1)
  return sid

-- | Unsubscribe from events
unsubscribe :: Broadcaster -> Int -> IO ()
unsubscribe broadcaster sid = do
  atomically $ modifyTVar' (bcSubscribers broadcaster) $ M.delete sid

-- | Append an event to the event store.
--
-- The payload is stored as real JSON, not as Haskell 'show' output, so the
-- jsonb column round-trips through 'getEvents'.
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
    , PersistText (TE.decodeUtf8 (LBS.toStrict (encode (eventEventData event))))
    , maybe PersistNull (PersistText . TE.decodeUtf8 . LBS.toStrict . encode) (eventEventMetadata event)
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

-- | One @event_store@ row: 10 columns, in SELECT order.
type EventRow =
  ( Single PersistValue, Single PersistValue, Single PersistValue
  , Single PersistValue, Single PersistValue, Single PersistValue
  , Single PersistValue, Single PersistValue, Single PersistValue
  , Single PersistValue )

-- | Parse one event row into an 'Event'
parseEventRow :: EventRow -> Event
parseEventRow (a, b, c, d, e, f, g, h, i, j) = Event
  { eventAggregateId    = persistToInt64 (unwrap a)
  , eventAggregateType  = persistToText (unwrap b)
  , eventEventType      = persistToText (unwrap c)
  , eventEventVersion   = fromIntegral (persistToInt64 (unwrap d))
  , eventSchemaVersion  = fromIntegral (persistToInt64 (unwrap e))
  , eventEventData      = decodeJSON (persistToText (unwrap f))
  , eventEventMetadata  = case unwrap g of
      PersistNull -> Nothing
      v           -> Just (decodeJSON (persistToText v))
  , eventSequenceNumber = persistToInt64 (unwrap h)
  , eventOccurredAt     = persistToTime (unwrap i)
  , eventCreatedAt      = persistToTime (unwrap j)
  }
  where
    unwrap :: Single PersistValue -> PersistValue
    unwrap (Single v) = v

-- | Get events for an aggregate
getEvents :: ConnectionPool -> Int64 -> Text -> IO (Either Text [Event])
getEvents pool aggId aggType = do
  let sql = "SELECT aggregate_id, aggregate_type, event_type, event_version, \
            \  event_schema_version, event_data, event_metadata, \
            \  sequence_number, occurred_at, created_at \
            \FROM event_store WHERE aggregate_id = ? AND aggregate_type = ? \
            \ORDER BY sequence_number ASC"
  rows <- runDb pool $ rawSql sql [PersistInt64 aggId, PersistText aggType] :: IO [EventRow]
  return $ Right $ map parseEventRow rows

-- | Get events from a specific sequence number
getEventsFrom :: ConnectionPool -> Int64 -> Text -> Int64 -> IO (Either Text [Event])
getEventsFrom pool aggId aggType fromSeq = do
  let sql = "SELECT aggregate_id, aggregate_type, event_type, event_version, \
            \  event_schema_version, event_data, event_metadata, \
            \  sequence_number, occurred_at, created_at \
            \FROM event_store WHERE aggregate_id = ? AND aggregate_type = ? \
            \  AND sequence_number >= ? \
            \ORDER BY sequence_number ASC"
  rows <- runDb pool $ rawSql sql [PersistInt64 aggId, PersistText aggType, PersistInt64 fromSeq] :: IO [EventRow]
  return $ Right $ map parseEventRow rows

-- | Replay events for an aggregate
replayAccount :: ConnectionPool -> Int64 -> Text -> IO (Either Text [Event])
replayAccount pool aggId aggType = getEvents pool aggId aggType

-- | Get latest sequence number for an aggregate
getLatestSequence :: ConnectionPool -> Int64 -> Text -> IO (Either Text (Maybe Int64))
getLatestSequence pool aggId aggType = do
  let sql = "SELECT MAX(sequence_number) FROM event_store WHERE aggregate_id = ? AND aggregate_type = ?"
  rows <- runDb pool $ rawSql sql [PersistInt64 aggId, PersistText aggType] :: IO [Single PersistValue]
  case rows of
    (Single (PersistInt64 n) : _) -> return $ Right $ Just n
    (Single PersistNull : _) -> return $ Right Nothing
    _ -> return $ Right Nothing

-- | Save a snapshot.
--
-- The table is @event_snapshot@ (singular) with @last_sequence_number@, as
-- created by V1005__event_store_snapshots.sql.
saveSnapshot :: ConnectionPool -> Snapshot -> IO (Either Text ())
saveSnapshot pool snap = do
  let sql = "INSERT INTO event_snapshot (\
            \  aggregate_id, aggregate_type, version, last_sequence_number, snapshot_data, created_at) \
            \VALUES (?, ?, ?, ?, ?, ?) \
            \ON CONFLICT (aggregate_id, aggregate_type, version) DO UPDATE SET \
            \  last_sequence_number = EXCLUDED.last_sequence_number, \
            \  snapshot_data = EXCLUDED.snapshot_data, created_at = EXCLUDED.created_at"
  result <- runDb pool $ rawExecute sql
    [ PersistInt64 (snapAggregateId snap)
    , PersistText (snapAggregateType snap)
    , PersistInt64 (fromIntegral $ snapVersion snap)
    , PersistInt64 (snapLastSeq snap)
    , PersistText (snapData snap)
    , PersistUTCTime (snapCreatedAt snap)
    ]
  return $ Right ()

-- | One @event_snapshots@ row: 6 columns, in SELECT order.
type SnapshotRow =
  ( Single PersistValue, Single PersistValue, Single PersistValue
  , Single PersistValue, Single PersistValue, Single PersistValue )

parseSnapshotRow :: SnapshotRow -> Snapshot
parseSnapshotRow (a, b, c, d, e, f) = Snapshot
  { snapAggregateId   = persistToInt64 (unwrap a)
  , snapAggregateType = persistToText (unwrap b)
  , snapVersion       = fromIntegral (persistToInt64 (unwrap c))
  , snapLastSeq       = persistToInt64 (unwrap d)
  , snapData          = persistToText (unwrap e)
  , snapCreatedAt     = persistToTime (unwrap f)
  }
  where
    unwrap :: Single PersistValue -> PersistValue
    unwrap (Single v) = v

-- | Get latest snapshot for an aggregate
getLatestSnapshot :: ConnectionPool -> Int64 -> Text -> IO (Either Text (Maybe Snapshot))
getLatestSnapshot pool aggId aggType = do
  let sql = "SELECT aggregate_id, aggregate_type, version, last_sequence_number, snapshot_data, created_at \
            \FROM event_snapshot WHERE aggregate_id = ? AND aggregate_type = ? \
            \ORDER BY version DESC LIMIT 1"
  rows <- runDb pool $ rawSql sql [PersistInt64 aggId, PersistText aggType] :: IO [SnapshotRow]
  return $ Right $ case rows of
    (row : _) -> Just (parseSnapshotRow row)
    []        -> Nothing

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

-- | Safe readMaybe
readMaybe :: Read a => String -> Maybe a
readMaybe s = case reads s of
  [(x, "")] -> Just x
  _ -> Nothing
