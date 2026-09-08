{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.EventStore
   ( Event (..),
     Snapshot (..),
     Broadcaster,
     currentEventSchemaVersion,
     appendEvent,
     appendEventBroadcast,
     getEvents,
     getEventsFrom,
     replayAccount,
     getLatestSequence,
     saveSnapshot,
     getLatestSnapshot,
     replayFromSnapshot,
     upgradeEvent,
     newBroadcaster,
     subscribe,
     unsubscribe,
   )
   where

import Control.Concurrent.STM
import Control.Monad (foldM)
import DAL.Database (ConnectionPool, runDb)
import DAL.Schema
  ( EventStoreEntity (..),
    EventSnapshotEntity (..),
    AccountingEventEntity (..),
    EntityField
      ( EventStoreEntityAggregateId
      , EventStoreEntityAggregateType
      , EventStoreEntityEventType
      , EventStoreEntityEventVersion
      , EventStoreEntityEventSchemaVersion
      , EventStoreEntityEventData
      , EventStoreEntityEventMetadata
      , EventStoreEntitySequenceNumber
      , EventStoreEntityOccurredAt
      , EventStoreEntityCreatedAt
      , EventSnapshotEntitySnapshotAggregateId
      , EventSnapshotEntitySnapshotAggregateType
      , EventSnapshotEntitySnapshotVersion
      , AccountingEventEntityEventId
      , AccountingEventEntityAggregateId
      , AccountingEventEntityAggregateType
      , AccountingEventEntityEventType
      , AccountingEventEntityEventVersion
      , AccountingEventEntityEventData
      , AccountingEventEntityMetadata
      , AccountingEventEntitySequenceNumber
      , AccountingEventEntityOccurredAt
      , AccountingEventEntityCreatedAt
      ),
  )
import Data.Aeson (Value, encode, decode)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, getCurrentTime)
import Database.Persist.Sql (insert, selectList, selectFirst, (==.), (>=.), entityVal)
import Database.Persist.Types (SelectOpt (Desc, Asc))
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

type BroadcastCallback = Int64 -> Text -> Text -> Value -> IO ()

newBroadcaster :: IO Broadcaster
newBroadcaster = do
  subs <- newTVarIO M.empty
  nid <- newTVarIO 0
  pure $ Broadcaster subs nid

subscribe :: Broadcaster -> BroadcastCallback -> IO Int
subscribe bc cb = atomically $ do
  n <- readTVar (bcNextId bc)
  writeTVar (bcNextId bc) (n + 1)
  modifyTVar' (bcSubscribers bc) (M.insert n cb)
  pure n

unsubscribe :: Broadcaster -> Int -> IO ()
unsubscribe bc n = atomically $
  modifyTVar' (bcSubscribers bc) (M.delete n)

broadcastEvent :: Broadcaster -> Int64 -> Text -> Text -> Value -> IO ()
broadcastEvent bc aggId aggType evType evData = do
  subs <- atomically $ readTVar (bcSubscribers bc)
  mapM_ (\cb -> cb aggId aggType evType evData) (M.elems subs)

decodeJSON :: Text -> Value
decodeJSON txt = case decode (LBS.fromStrict $ TE.encodeUtf8 txt) of
  Just v  -> v
  Nothing -> error "Invalid JSON in database"

encodeJSON :: Value -> Text
encodeJSON v = TE.decodeUtf8 $ LBS.toStrict $ encode v

decodeMaybeJSON :: Maybe Text -> Maybe Value
decodeMaybeJSON Nothing   = Nothing
decodeMaybeJSON (Just t) = case decode (LBS.fromStrict $ TE.encodeUtf8 t) of
  Just v  -> Just v
  Nothing -> Nothing

entityToEvent :: EventStoreEntity -> Event
entityToEvent entity =
  Event
    { eventAggregateId    = eventStoreEntityAggregateId entity
    , eventAggregateType  = eventStoreEntityAggregateType entity
    , eventEventType      = eventStoreEntityEventType entity
    , eventEventVersion   = eventStoreEntityEventVersion entity
    , eventSchemaVersion  = eventStoreEntityEventSchemaVersion entity
    , eventEventData      = decodeJSON (eventStoreEntityEventData entity)
    , eventEventMetadata  = decodeMaybeJSON (eventStoreEntityEventMetadata entity)
    , eventSequenceNumber = eventStoreEntitySequenceNumber entity
    , eventOccurredAt     = eventStoreEntityOccurredAt entity
    , eventCreatedAt      = eventStoreEntityCreatedAt entity
    }

entityToSnapshot :: EventSnapshotEntity -> Snapshot
entityToSnapshot entity =
  Snapshot
    { snapAggregateId   = eventSnapshotEntitySnapshotAggregateId entity
    , snapAggregateType = eventSnapshotEntitySnapshotAggregateType entity
    , snapVersion       = eventSnapshotEntitySnapshotVersion entity
    , snapLastSeq       = eventSnapshotEntitySnapshotLastSeq entity
    , snapData          = eventSnapshotEntitySnapshotData entity
    , snapCreatedAt     = eventSnapshotEntitySnapshotCreatedAt entity
    }

getLatestSequence :: ConnectionPool -> Int64 -> Text -> IO (Either Text (Maybe Int64))
getLatestSequence pool aggId aggType = do
  result <- runDb pool $ selectFirst
    [ EventStoreEntityAggregateId ==. aggId
    , EventStoreEntityAggregateType ==. aggType
    ] [Desc EventStoreEntitySequenceNumber]
  pure $ Right $ fmap (eventStoreEntitySequenceNumber . entityVal) result

appendEvent :: ConnectionPool -> Int64 -> Text -> Text -> Int -> Int -> Value -> Maybe Value -> Int64 -> IO (Either Text ())
appendEvent pool aggId aggType evType evVer evSchemaVer evData evMeta seqNum = do
  now <- getCurrentTime
  let entity = EventStoreEntity
        { eventStoreEntityAggregateId       = aggId
        , eventStoreEntityAggregateType     = aggType
        , eventStoreEntityEventType         = evType
        , eventStoreEntityEventVersion      = evVer
        , eventStoreEntityEventSchemaVersion = evSchemaVer
        , eventStoreEntityEventData         = encodeJSON evData
        , eventStoreEntityEventMetadata     = fmap encodeJSON evMeta
        , eventStoreEntitySequenceNumber    = seqNum
        , eventStoreEntityOccurredAt        = now
        , eventStoreEntityCreatedAt         = now
        }
  runDb pool $ insert entity
  pure $ Right ()

appendEventBroadcast :: ConnectionPool -> Broadcaster -> Int64 -> Text -> Text -> Int -> Int -> Value -> Maybe Value -> Int64 -> Text -> IO (Either Text ())
appendEventBroadcast pool broadcaster aggId aggType evType evVer evSchemaVer evData evMeta seqNum _room = do
  result <- appendEvent pool aggId aggType evType evVer evSchemaVer evData evMeta seqNum
  broadcastEvent broadcaster aggId aggType evType evData
  pure result

getEvents :: ConnectionPool -> Int64 -> Text -> IO (Either Text [Event])
getEvents pool aggId aggType = do
  result <- runDb pool $ selectList
    [ EventStoreEntityAggregateId ==. aggId
    , EventStoreEntityAggregateType ==. aggType
    ] [Asc EventStoreEntitySequenceNumber]
  pure $ Right $ map (entityToEvent . entityVal) result

getEventsFrom :: ConnectionPool -> Int64 -> Text -> Int64 -> IO (Either Text [Event])
getEventsFrom pool aggId aggType seqFrom = do
  result <- runDb pool $ selectList
    [ EventStoreEntityAggregateId ==. aggId
    , EventStoreEntityAggregateType ==. aggType
    , EventStoreEntitySequenceNumber >=. seqFrom
    ] [Asc EventStoreEntitySequenceNumber]
  pure $ Right $ map (entityToEvent . entityVal) result

replayAccount :: ConnectionPool -> Int64 -> IO (Either Text [Event])
replayAccount pool accountId = do
  result <- runDb pool $ selectList
    [ EventStoreEntityAggregateId ==. accountId
    ] [Asc EventStoreEntitySequenceNumber]
  pure $ Right $ map (entityToEvent . entityVal) result

-- | Save a snapshot for an aggregate at a given version
saveSnapshot :: ConnectionPool -> Int64 -> Text -> Int -> Int64 -> Text -> IO (Either Text ())
saveSnapshot pool aggId aggType version lastSeq snapData = do
  now <- getCurrentTime
  let entity = EventSnapshotEntity
        { eventSnapshotEntitySnapshotAggregateId   = aggId
        , eventSnapshotEntitySnapshotAggregateType = aggType
        , eventSnapshotEntitySnapshotVersion       = version
        , eventSnapshotEntitySnapshotLastSeq        = lastSeq
        , eventSnapshotEntitySnapshotData          = snapData
        , eventSnapshotEntitySnapshotCreatedAt     = now
        }
  runDb pool $ insert entity
  pure $ Right ()

-- | Get the latest snapshot for an aggregate
getLatestSnapshot :: ConnectionPool -> Int64 -> Text -> IO (Either Text (Maybe Snapshot))
getLatestSnapshot pool aggId aggType = do
  result <- runDb pool $ selectFirst
    [ EventSnapshotEntitySnapshotAggregateId ==. aggId
    , EventSnapshotEntitySnapshotAggregateType ==. aggType
    ] [Desc EventSnapshotEntitySnapshotVersion]
  pure $ Right $ fmap (entityToSnapshot . entityVal) result

-- | Replay events from the latest snapshot version
-- Falls back to full replay if no snapshot exists
replayFromSnapshot :: ConnectionPool -> Int64 -> Text -> IO (Either Text [Event])
replayFromSnapshot pool aggId aggType = do
  snapResult <- getLatestSnapshot pool aggId aggType
  case snapResult of
    Left err -> pure (Left err)
    Right Nothing -> getEvents pool aggId aggType
    Right (Just snap) -> getEventsFrom pool aggId aggType (snapLastSeq snap + 1)

-- | Upgrade event payload from one schema version to the current version
-- Returns Left if the version is newer than current (downgrade not supported)
upgradeEvent :: Int -> BS.ByteString -> Either String BS.ByteString
upgradeEvent fromVersion payload
  | fromVersion == currentEventSchemaVersion = Right payload
  | fromVersion < currentEventSchemaVersion = upgradeToLatest fromVersion payload
  | otherwise = Left $ "Event schema version " ++ show fromVersion
                    ++ " is newer than current " ++ show currentEventSchemaVersion
                    ++ " (downgrade not supported)"

upgradeToLatest :: Int -> BS.ByteString -> Either String BS.ByteString
upgradeToLatest fromVersion payload =
  foldM upgradeStep payload [fromVersion .. currentEventSchemaVersion - 1]

upgradeStep :: BS.ByteString -> Int -> Either String BS.ByteString
upgradeStep payload _ = Right payload
