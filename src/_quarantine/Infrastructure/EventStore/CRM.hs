-- | CRM Event Store - Append-only event store for CRM operations
-- Implements CRM-07: Event sourcing audit trail for CRM
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Infrastructure.EventStore.CRM
  ( CRMEvent   (..)
  , ContactCreated   (..)
  , ContactUpdated   (..)
  , ContactDeleted   (..)
  , CompanyCreated   (..)
  , CompanyUpdated   (..)
  , DealCreated   (..)
  , DealUpdated   (..)
  , DealStageChanged   (..)
  , ActivityLogged   (..)
  , CRMEventStore   (..)
  , mkCRMEventStore
  , appendCRMEvent
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime)
import GHC.Generics (Generic)
import Data.Aeson (ToJSON, toJSON)
import Data.Aeson.TH (deriveJSON, defaultOptions)
import DAL.Database (Pool)
import qualified DAL.EventStore as ES

-- | Contact created event payload
data ContactCreated = ContactCreated
  { ccContactId :: Int64
  , ccFirstName :: Text
  , ccLastName :: Text
  , ccEmail :: Maybe Text
  , ccPhone :: Maybe Text
  , ccCompanyId :: Maybe Int64
  , ccTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''ContactCreated)

-- | Contact updated event payload
data ContactUpdated = ContactUpdated
  { cuContactId :: Int64
  , cuFirstName :: Text
  , cuLastName :: Text
  , cuEmail :: Maybe Text
  , cuPhone :: Maybe Text
  , cuCompanyId :: Maybe Int64
  , cuTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''ContactUpdated)

-- | Contact deleted event payload
data ContactDeleted = ContactDeleted
  { cdContactId :: Int64
  , cdReason :: Text
  , cdTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''ContactDeleted)

-- | Company created event payload
data CompanyCreated = CompanyCreated
  { cocCompanyId :: Int64
  , cocName :: Text
  , cocEmail :: Maybe Text
  , cocPhone :: Maybe Text
  , cocWebsite :: Maybe Text
  , cocIndustry :: Maybe Text
  , cocTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''CompanyCreated)

-- | Company updated event payload
data CompanyUpdated = CompanyUpdated
  { couCompanyId :: Int64
  , couName :: Text
  , couEmail :: Maybe Text
  , couPhone :: Maybe Text
  , couWebsite :: Maybe Text
  , couIndustry :: Maybe Text
  , couTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''CompanyUpdated)

-- | Deal created event payload
data DealCreated = DealCreated
  { dcDealId :: Int64
  , dcName :: Text
  , dcValue :: Double
  , dcStageId :: Int64
  , dcContactId :: Maybe Int64
  , dcCompanyId :: Maybe Int64
  , dcTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''DealCreated)

-- | Deal updated event payload
data DealUpdated = DealUpdated
  { duDealId :: Int64
  , duName :: Text
  , duValue :: Double
  , duStageId :: Int64
  , duContactId :: Maybe Int64
  , duCompanyId :: Maybe Int64
  , duTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''DealUpdated)

-- | Deal stage changed event payload
data DealStageChanged = DealStageChanged
  { dscDealId :: Int64
  , dscFromStageId :: Int64
  , dscToStageId :: Int64
  , dscTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''DealStageChanged)

-- | Activity logged event payload
data ActivityLogged = ActivityLogged
  { alActivityId :: Int64
  , alDealId :: Int64
  , alActivityType :: Text
  , alSubject :: Text
  , alDescription :: Text
  , alTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''ActivityLogged)

-- | CRM event types - every state change captured as an event
data CRMEvent
  = ContactCreatedEvent ContactCreated
  | ContactUpdatedEvent ContactUpdated
  | ContactDeletedEvent ContactDeleted
  | CompanyCreatedEvent CompanyCreated
  | CompanyUpdatedEvent CompanyUpdated
  | DealCreatedEvent DealCreated
  | DealUpdatedEvent DealUpdated
  | DealStageChangedEvent DealStageChanged
  | ActivityLoggedEvent ActivityLogged
  deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''CRMEvent)

-- | Event store for CRM events using PostgreSQL back-end
data CRMEventStore = CRMEventStore
  { cesPool :: Pool
  , cesStreamName :: Text
  }

-- | Create a new CRM event store
mkCRMEventStore :: Pool -> Text -> CRMEventStore
mkCRMEventStore pool streamName =
  CRMEventStore
    { cesPool = pool
    , cesStreamName = streamName
    }

-- | Helper to extract metadata from event
getEventInfo :: CRMEvent -> (Int64, Text, Text)
getEventInfo (ContactCreatedEvent ev) = (ccContactId ev, "crm_contact", "ContactCreated")
getEventInfo (ContactUpdatedEvent ev) = (cuContactId ev, "crm_contact", "ContactUpdated")
getEventInfo (ContactDeletedEvent ev) = (cdContactId ev, "crm_contact", "ContactDeleted")
getEventInfo (CompanyCreatedEvent ev) = (cocCompanyId ev, "crm_company", "CompanyCreated")
getEventInfo (CompanyUpdatedEvent ev) = (couCompanyId ev, "crm_company", "CompanyUpdated")
getEventInfo (DealCreatedEvent ev) = (dcDealId ev, "crm_deal", "DealCreated")
getEventInfo (DealUpdatedEvent ev) = (duDealId ev, "crm_deal", "DealUpdated")
getEventInfo (DealStageChangedEvent ev) = (dscDealId ev, "crm_deal", "DealStageChanged")
getEventInfo (ActivityLoggedEvent ev) = (alDealId ev, "crm_deal", "ActivityLogged")

-- | Append an event to the store
appendCRMEvent :: CRMEventStore -> CRMEvent -> IO (Either Text ())
appendCRMEvent store event = do
  let (aggId, aggType, evType) = getEventInfo event
  -- Get latest sequence to increment
  latestSeqRes <- ES.getLatestSequence (cesPool store) aggId aggType
  case latestSeqRes of
    Left err -> pure $ Left err
    Right latestSeq -> do
      let nextSeq = case latestSeq of
            Nothing -> 1
            Just s  -> s + 1
      ES.appendEvent (cesPool store)
        aggId
        aggType
        evType
        1 -- version
        1 -- schema version
        (toJSON event)
        Nothing
        nextSeq