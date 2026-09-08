-- | Inventory Event Store - Append-only event store for inventory operations
-- Implements US-3-2: Event-sourced inventory with stock replay
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Infrastructure.EventStore.Inventory
  ( InventoryEvent   (..)
  , StockReceived   (..)
  , StockShipped   (..)
  , StockTransferred   (..)
  , StockAdjusted   (..)
  , StockWrittenOff   (..)
  , InventoryEventStore   (..)
  , mkInventoryEventStore
  , appendInventoryEvent
  , readInventoryEvents
  , replayInventoryEvents
  , StockSnapshot   (..)
  , getStockSnapshot
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

-- | Stock received event payload
data StockReceived = StockReceived
  { srGoodsId :: Int64
  , srLocationId :: Int64
  , srQty :: Double
  , srBatchId :: Maybe Int64
  , srTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''StockReceived)

-- | Stock shipped event payload
data StockShipped = StockShipped
  { ssGoodsId :: Int64
  , ssLocationId :: Int64
  , ssQty :: Double
  , ssTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''StockShipped)

-- | Stock transferred event payload
data StockTransferred = StockTransferred
  { stGoodsId :: Int64
  , stFromLocationId :: Int64
  , stToLocationId :: Int64
  , stQty :: Double
  , stTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''StockTransferred)

-- | Stock adjusted event payload
data StockAdjusted = StockAdjusted
  { saGoodsId :: Int64
  , saLocationId :: Int64
  , saQtyDelta :: Double
  , saReason :: Text
  , saTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''StockAdjusted)

-- | Stock written off event payload
data StockWrittenOff = StockWrittenOff
  { swGoodsId :: Int64
  , swLocationId :: Int64
  , swQty :: Double
  , swReason :: Text
  , swTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''StockWrittenOff)

-- | Inventory event types
data InventoryEvent
  = StockReceivedEvent StockReceived
  | StockShippedEvent StockShipped
  | StockTransferredEvent StockTransferred
  | StockAdjustedEvent StockAdjusted
  | StockWrittenOffEvent StockWrittenOff
  deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''InventoryEvent)

-- | Current stock state for a goods at a location
data StockSnapshot = StockSnapshot
  { ssGoodsIdSnap :: Int64
  , ssLocationIdSnap :: Int64
  , ssBalance :: Double
  , ssLastUpdated :: UTCTime
  } deriving (Show, Eq, Generic)

-- | Event store for inventory events
data InventoryEventStore = InventoryEventStore
  { iesPool :: ConnectionPool
  , iesStreamName :: Text
  }

-- | Create a new inventory event store
mkInventoryEventStore :: ConnectionPool -> Text -> InventoryEventStore
mkInventoryEventStore pool streamName =
  InventoryEventStore
    { iesPool = pool
    , iesStreamName = streamName
    }

-- | Helper to extract metadata from inventory event
getEventInfo :: InventoryEvent -> (Int64, Text, Text)
getEventInfo (StockReceivedEvent ev) = (srGoodsId ev, "goods_stock", "StockReceived")
getEventInfo (StockShippedEvent ev) = (ssGoodsId ev, "goods_stock", "StockShipped")
getEventInfo (StockTransferredEvent ev) = (stGoodsId ev, "goods_stock", "StockTransferred")
getEventInfo (StockAdjustedEvent ev) = (saGoodsId ev, "goods_stock", "StockAdjusted")
getEventInfo (StockWrittenOffEvent ev) = (swGoodsId ev, "goods_stock", "StockWrittenOff")

-- | Append an inventory event
appendInventoryEvent :: InventoryEventStore -> InventoryEvent -> IO (Either Text ())
appendInventoryEvent store event = do
  let (aggId, aggType, evType) = getEventInfo event
  latestSeqRes <- ES.getLatestSequence (iesPool store) aggId aggType
  case latestSeqRes of
    Left err -> pure $ Left err
    Right latestSeq -> do
      let nextSeq = case latestSeq of
            Nothing -> 1
            Just seq -> seq + 1
      ES.appendEvent (iesPool store)
        aggId
        aggType
        evType
        1
        1 -- schema version
        (toJSON event)
        Nothing
        nextSeq

-- | Read events for a goods item
readInventoryEvents :: InventoryEventStore -> Int64 -> IO (Either Text [InventoryEvent])
readInventoryEvents store goodsId = do
  res <- ES.getEvents (iesPool store) goodsId "goods_stock"
  case res of
    Left err -> pure $ Left err
    Right rawEvents -> pure $ Right $ map decodeEvent rawEvents
  where
    decodeEvent e = case fromJSON (ES.eventEventData e) of
      Success ev -> ev
      Error err -> error $ "Failed to decode inventory event: " ++ err

-- | Replay events to get stock snapshot
replayInventoryEvents :: [InventoryEvent] -> Map (Int64, Int64) StockSnapshot
replayInventoryEvents events =
  L.foldl' applyEvent M.empty events

applyEvent :: Map (Int64, Int64) StockSnapshot -> InventoryEvent -> Map (Int64, Int64) StockSnapshot
applyEvent state (StockReceivedEvent ev) =
  M.insertWith update (srGoodsId ev, srLocationId ev) (initSnap (srGoodsId ev) (srLocationId ev) (srQty ev) (srTimestamp ev)) state
  where
    update _ existing = existing { ssBalance = ssBalance existing + srQty ev, ssLastUpdated = srTimestamp ev }
applyEvent state (StockShippedEvent ev) =
  M.insertWith update (ssGoodsId ev, ssLocationId ev) (initSnap (ssGoodsId ev) (ssLocationId ev) (-ssQty ev) (ssTimestamp ev)) state
  where
    update _ existing = existing { ssBalance = ssBalance existing - ssQty ev, ssLastUpdated = ssTimestamp ev }
applyEvent state (StockTransferredEvent ev) =
  let state' = M.insertWith updateFrom (stGoodsId ev, stFromLocationId ev) (initSnap (stGoodsId ev) (stFromLocationId ev) (-stQty ev) (stTimestamp ev)) state
  in M.insertWith updateTo (stGoodsId ev, stToLocationId ev) (initSnap (stGoodsId ev) (stToLocationId ev) (stQty ev) (stTimestamp ev)) state'
  where
    updateFrom _ existing = existing { ssBalance = ssBalance existing - stQty ev, ssLastUpdated = stTimestamp ev }
    updateTo _ existing = existing { ssBalance = ssBalance existing + stQty ev, ssLastUpdated = stTimestamp ev }
applyEvent state (StockAdjustedEvent ev) =
  M.insertWith update (saGoodsId ev, saLocationId ev) (initSnap (saGoodsId ev) (saLocationId ev) (saQtyDelta ev) (saTimestamp ev)) state
  where
    update _ existing = existing { ssBalance = ssBalance existing + saQtyDelta ev, ssLastUpdated = saTimestamp ev }
applyEvent state (StockWrittenOffEvent ev) =
  M.insertWith update (swGoodsId ev, swLocationId ev) (initSnap (swGoodsId ev) (swLocationId ev) (-swQty ev) (swTimestamp ev)) state
  where
    update _ existing = existing { ssBalance = ssBalance existing - swQty ev, ssLastUpdated = swTimestamp ev }

initSnap :: Int64 -> Int64 -> Double -> UTCTime -> StockSnapshot
initSnap gid lid bal time = StockSnapshot gid lid bal time

-- | Get current stock snapshot for a goods at all locations
getStockSnapshot :: InventoryEventStore -> Int64 -> IO (Either Text (Map (Int64, Int64) StockSnapshot))
getStockSnapshot store goodsId = do
  res <- readInventoryEvents store goodsId
  case res of
    Left err -> pure $ Left err
    Right events -> pure $ Right $ replayInventoryEvents events
