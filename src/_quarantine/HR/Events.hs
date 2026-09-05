{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module HR.Events
  ( -- * Event types
    HREvent   (..),
    PersonEventData   (..),
    RelationEventData   (..),
    EventStore,

    -- * Event operations
    recordEvent,
    queryEvents,
    queryEventsByPerson,
    queryEventsByType,

    -- * Event store
    newEventStore,
    getEventHistory,
    getEventCount,
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import Data.IORef (IORef, newIORef, readIORef, modifyIORef)
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)

-- | Person event data
data PersonEventData
  = PersonCreated
      { pedPersonId :: Int64
      , pedName :: Text
      , pedCode :: Text
      }
  | PersonUpdated
      { pedPersonId :: Int64
      , pedFieldChanged :: Text
      , pedOldValue :: Text
      , pedNewValue :: Text
      }
  | PersonStatusChanged
      { pedPersonId :: Int64
      , pedOldStatus :: Text
      , pedNewStatus :: Text
      }
  | PersonDeleted
      { pedPersonId :: Int64
      , pedName :: Text
      }
  deriving (Show, Eq, Generic)

instance ToJSON PersonEventData
instance FromJSON PersonEventData

-- | Relation event data
data RelationEventData
  = RelationCreated
      { redFromPersonId :: Int64
      , redToPersonId :: Int64
      , redType :: Text
      }
  | RelationEnded
      { redRelationId :: Int64
      , redFromPersonId :: Int64
      , redToPersonId :: Int64
      }
  deriving (Show, Eq, Generic)

instance ToJSON RelationEventData
instance FromJSON RelationEventData

-- | HR Event
data HREvent
  = PersonEvent
      { eventId :: Int64
      , eventTimestamp :: UTCTime
      , eventPersonId :: Maybe Int64
      , eventPersonData :: PersonEventData
      , eventUserId :: Maybe Int64
      }
  | RelationEvent
      { eventId :: Int64
      , eventTimestamp :: UTCTime
      , eventRelationData :: RelationEventData
      , eventUserId :: Maybe Int64
      }
  deriving (Show, Eq, Generic)

instance ToJSON HREvent
instance FromJSON HREvent

-- | Event store (in-memory)
type EventStore = IORef [HREvent]

-- | Create new event store
newEventStore :: IO EventStore
newEventStore = newIORef []

-- | Record an event
recordEvent :: EventStore -> HREvent -> IO ()
recordEvent store event = modifyIORef store (event :)

-- | Query all events
queryEvents :: EventStore -> IO [HREvent]
queryEvents store = do
  events <- readIORef store
  return (reverse events)

-- | Query events by person ID
queryEventsByPerson :: EventStore -> Int64 -> IO [HREvent]
queryEventsByPerson store personId = do
  events <- queryEvents store
  return $ filter (\e -> case e of
    PersonEvent { eventPersonId = Just pid } -> pid == personId
    _ -> False) events

-- | Query events by type (PersonEvent or RelationEvent)
queryEventsByType :: EventStore -> String -> IO [HREvent]
queryEventsByType store eventType = do
  events <- queryEvents store
  return $ case eventType of
    "person" -> filter (\e -> case e of PersonEvent {} -> True; _ -> False) events
    "relation" -> filter (\e -> case e of RelationEvent {} -> True; _ -> False) events
    _ -> []

-- | Get full event history
getEventHistory :: EventStore -> IO [HREvent]
getEventHistory = queryEvents

-- | Get event count
getEventCount :: EventStore -> IO Int
getEventCount store = do
  events <- readIORef store
  return (length events)

-- | Create person created event
personCreatedEvent :: Int64 -> UTCTime -> Int64 -> Text -> Text -> Maybe Int64 -> HREvent
personCreatedEvent eventId ts personId name code userId =
  PersonEvent
    { eventId = eventId
    , eventTimestamp = ts
    , eventPersonId = Just personId
    , eventPersonData = PersonCreated personId name code
    , eventUserId = userId
    }

-- | Create person updated event
personUpdatedEvent :: Int64 -> UTCTime -> Int64 -> Text -> Text -> Text -> Maybe Int64 -> HREvent
personUpdatedEvent eventId ts personId fieldName oldVal newVal userId =
  PersonEvent
    { eventId = eventId
    , eventTimestamp = ts
    , eventPersonId = Just personId
    , eventPersonData = PersonUpdated personId fieldName oldVal newVal
    , eventUserId = userId
    }

-- | Create person status changed event
personStatusChangedEvent :: Int64 -> UTCTime -> Int64 -> Text -> Text -> Maybe Int64 -> HREvent
personStatusChangedEvent eventId ts personId oldStatus newStatus userId =
  PersonEvent
    { eventId = eventId
    , eventTimestamp = ts
    , eventPersonId = Just personId
    , eventPersonData = PersonStatusChanged personId oldStatus newStatus
    , eventUserId = userId
    }

-- | Create person deleted event
personDeletedEvent :: Int64 -> UTCTime -> Int64 -> Text -> Maybe Int64 -> HREvent
personDeletedEvent eventId ts personId name userId =
  PersonEvent
    { eventId = eventId
    , eventTimestamp = ts
    , eventPersonId = Just personId
    , eventPersonData = PersonDeleted personId name
    , eventUserId = userId
    }

-- | Create relation created event
relationCreatedEvent :: Int64 -> UTCTime -> Int64 -> Int64 -> Text -> Maybe Int64 -> HREvent
relationCreatedEvent eventId ts fromPersonId toPersonId relType userId =
  RelationEvent
    { eventId = eventId
    , eventTimestamp = ts
    , eventRelationData = RelationCreated fromPersonId toPersonId relType
    , eventUserId = userId
    }

-- | Create relation ended event
relationEndedEvent :: Int64 -> UTCTime -> Int64 -> Int64 -> Int64 -> Maybe Int64 -> HREvent
relationEndedEvent eventId ts relationId fromPersonId toPersonId userId =
  RelationEvent
    { eventId = eventId
    , eventTimestamp = ts
    , eventRelationData = RelationEnded relationId fromPersonId toPersonId
    , eventUserId = userId
    }
