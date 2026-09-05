-- | Accounting Event Store - Append-only event store for accounting operations
-- Implements US-3-1: Event-sourced accounting with replay capability
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Infrastructure.EventStore.Accounting
  ( AccountingEvent   (..)
  , AccountCreated   (..)
  , JournalEntryPosted   (..)
  , EntryReverted   (..)
  , EntryCancelled   (..)
  , AccountFrozen   (..)
  , AccountUnfrozen   (..)
  , AccountingEventStore   (..)
  , mkAccountingEventStore
  , appendAccountingEvent
  , readAccountEvents
  , replayAccountEvents
  , reconstructAccountBalance
  , AccountSnapshot   (..)
  , getAccountSnapshot
  , projectCurrentState
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime, getCurrentTime)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import qualified Data.List as L
import GHC.Generics (Generic)
import Data.Aeson (ToJSON, FromJSON, toJSON, fromJSON, Result  (..))
import Data.Aeson.TH (deriveJSON, defaultOptions)
import DAL.ORMPool (ConnectionPool)
import qualified DAL.EventStore as ES

-- | Account created event payload
data AccountCreated = AccountCreated
  { acAccountId :: Int64
  , acCode :: Text
  , acName :: Text
  , acType :: Text
  , acParentId :: Maybe Int64
  , acTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''AccountCreated)

-- | Journal entry posted event payload
data JournalEntryPosted = JournalEntryPosted
  { jepEntryId :: Int64
  , jepDebitAcc :: Int64
  , jepCreditAcc :: Int64
  , jepAmount :: Double
  , jepCurrency :: Text
  , jepDescription :: Text
  , jepDate :: Day
  , jepTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''JournalEntryPosted)

-- | Entry reverted event payload
data EntryReverted = EntryReverted
  { ervOriginalEntryId :: Int64
  , ervRevertedById :: Int64
  , ervReason :: Text
  , ervTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''EntryReverted)

-- | Entry cancelled event payload
data EntryCancelled = EntryCancelled
  { ecOriginalEntryId :: Int64
  , ecCancelledById :: Int64
  , ecReason :: Text
  , ecTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''EntryCancelled)

-- | Account frozen event payload
data AccountFrozen = AccountFrozen
  { afAccountId :: Int64
  , afFrozenById :: Int64
  , afReason :: Text
  , afTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''AccountFrozen)

-- | Account unfrozen event payload
data AccountUnfrozen = AccountUnfrozen
  { ufAccountId :: Int64
  , ufUnfrozenById :: Int64
  , ufReason :: Text
  , ufTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''AccountUnfrozen)

-- | Accounting event types - every state change captured as an event
data AccountingEvent
  = AccountCreatedEvent AccountCreated
  | JournalEntryPostedEvent JournalEntryPosted
  | EntryRevertedEvent EntryReverted
  | EntryCancelledEvent EntryCancelled
  | AccountFrozenEvent AccountFrozen
  | AccountUnfrozenEvent AccountUnfrozen
  deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''AccountingEvent)

-- | Projected account state (result of replay)
data AccountSnapshot = AccountSnapshot
  { asAccountId :: Int64
  , asCode :: Text
  , asName :: Text
  , asType :: Text
  , asDebitTotal :: Double
  , asCreditTotal :: Double
  , asBalance :: Double
  , asIsFrozen :: Bool
  , asEntryCount :: Int
  } deriving (Show, Eq, Generic)

-- | Helper to extract metadata from accounting event
getEventInfo :: AccountingEvent -> (Int64, Text, Text)
getEventInfo (AccountCreatedEvent ev) = (acAccountId ev, "account", "AccountCreated")
getEventInfo (JournalEntryPostedEvent ev) = (jepEntryId ev, "journal_entry", "JournalEntryPosted")
getEventInfo (EntryRevertedEvent ev) = (ervOriginalEntryId ev, "journal_entry", "EntryReverted")
getEventInfo (EntryCancelledEvent ev) = (ecOriginalEntryId ev, "journal_entry", "EntryCancelled")
getEventInfo (AccountFrozenEvent ev) = (afAccountId ev, "account", "AccountFrozen")
getEventInfo (AccountUnfrozenEvent ev) = (ufAccountId ev, "account", "AccountUnfrozen")

-- | Event store for accounting events using PostgreSQL back-end
data AccountingEventStore = AccountingEventStore
  { aesPool :: ConnectionPool
  , aesStreamName :: Text
  }

-- | Create a new accounting event store
mkAccountingEventStore :: ConnectionPool -> Text -> AccountingEventStore
mkAccountingEventStore pool streamName =
  AccountingEventStore
    { aesPool = pool
    , aesStreamName = streamName
    }

-- | Append an event to the store
appendAccountingEvent :: AccountingEventStore -> AccountingEvent -> IO (Either Text ())
appendAccountingEvent store event = do
  let (aggId, aggType, evType) = getEventInfo event
  -- Get latest sequence to increment
  latestSeqRes <- ES.getLatestSequence (aesPool store) aggId aggType
  case latestSeqRes of
    Left err -> pure $ Left err
    Right latestSeq -> do
      let nextSeq = case latestSeq of
            Nothing -> 1
            Just seq -> seq + 1
      ES.appendEvent (aesPool store)
        aggId
        aggType
        evType
        1 -- version
        1 -- schema version
        (toJSON event)
        Nothing
        nextSeq

-- | Read events for an account stream
readAccountEvents :: AccountingEventStore -> Int64 -> IO (Either Text [AccountingEvent])
readAccountEvents store accountId = do
  res <- ES.replayAccount (aesPool store) accountId
  case res of
    Left err -> pure $ Left err
    Right rawEvents -> pure $ Right $ map decodeEvent rawEvents
  where
    decodeEvent e = case fromJSON (ES.eventEventData e) of
      Success ev -> ev
      Error err -> error $ "Failed to decode accounting event: " ++ err


-- | Replay events to reconstruct account state
replayAccountEvents :: [AccountingEvent] -> Map Int64 AccountSnapshot
replayAccountEvents events =
  L.foldl' applyEvent M.empty events

-- | Apply a single event to current state
applyEvent :: Map Int64 AccountSnapshot -> AccountingEvent -> Map Int64 AccountSnapshot
applyEvent state (AccountCreatedEvent ev) =
  M.insert (acAccountId ev) AccountSnapshot
    { asAccountId = acAccountId ev
    , asCode = acCode ev
    , asName = acName ev
    , asType = acType ev
    , asDebitTotal = 0
    , asCreditTotal = 0
    , asBalance = 0
    , asIsFrozen = False
    , asEntryCount = 0
    } state
applyEvent state (JournalEntryPostedEvent ev) =
  M.adjust updateDebit (jepDebitAcc ev) $
  M.adjust updateCredit (jepCreditAcc ev) state
  where
    updateDebit snap = snap
      { asDebitTotal = asDebitTotal snap + jepAmount ev
      , asBalance = asBalance snap + jepAmount ev
      , asEntryCount = asEntryCount snap + 1
      }
    updateCredit snap = snap
      { asCreditTotal = asCreditTotal snap + jepAmount ev
      , asBalance = asBalance snap - jepAmount ev
      , asEntryCount = asEntryCount snap + 1
      }
applyEvent state (EntryRevertedEvent _ev) = state
applyEvent state (EntryCancelledEvent _ev) = state
applyEvent state (AccountFrozenEvent ev) =
  M.adjust (\snap -> snap { asIsFrozen = True }) (afAccountId ev) state
applyEvent state (AccountUnfrozenEvent ev) =
  M.adjust (\snap -> snap { asIsFrozen = False }) (ufAccountId ev) state

-- | Reconstruct a single account balance from its events
reconstructAccountBalance :: Int64 -> [AccountingEvent] -> Maybe AccountSnapshot
reconstructAccountBalance accountId events =
  M.lookup accountId (replayAccountEvents events)

-- | Get current snapshot for an account
getAccountSnapshot :: AccountingEventStore -> Int64 -> IO (Either Text (Maybe AccountSnapshot))
getAccountSnapshot store accountId = do
  res <- readAccountEvents store accountId
  case res of
    Left err -> pure $ Left err
    Right events -> pure $ Right $ reconstructAccountBalance accountId events

-- | Get full projected state for a specific account
projectCurrentState :: AccountingEventStore -> Int64 -> IO (Either Text (Map Int64 AccountSnapshot))
projectCurrentState store accountId = do
  res <- readAccountEvents store accountId
  case res of
    Left err -> pure $ Left err
    Right events -> pure $ Right $ replayAccountEvents events