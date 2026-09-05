{-# LANGUAGE OverloadedStrings #-}
-- | WebSocket-EventBus integration for real-time notifications
-- Broadcasts events to WebSocket clients when events occur
module Surypus.WebSocket.Integration where

import Control.Concurrent.STM
import Control.Monad (forever)
import Data.Text (Text)
import qualified Data.Text as T
import Surypus.WebSocket
import Integration.API.EventBusAdvanced

-- | Start WebSocket event broadcaster
startEventBroadcaster :: WebSocketHandler -> EventBusAdvanced -> IO ()
startEventBroadcaster wsHandler bus = forever $ do
  msg <- consumeAdvanced bus
  case msg of
    Just busMsg -> broadcastEvent wsHandler busMsg
    Nothing -> return ()

-- | Broadcast event to appropriate room
broadcastEvent :: WebSocketHandler -> BusMessage -> IO ()
broadcastEvent wsHandler msg = do
  let room = getRoomForMessage msg
  let payload = encodeMessage msg
  broadcastToRoom wsHandler room payload

-- | Determine room from message routing key
getRoomForMessage :: BusMessage -> Text
getRoomForMessage msg =
  case msgRoutingKey msg of
    key | "bill" `T.isPrefixOf` key -> "bills"
    key | "stock" `T.isPrefixOf` key -> "inventory"
    key | "person" `T.isPrefixOf` key -> "persons"
    _ -> "notifications"

-- | Encode message to JSON text
encodeMessage :: BusMessage -> Text
encodeMessage msg =
  "{ \"id\": \"" <> msgId msg <> "\", \"routingKey\": \"" <> msgRoutingKey msg <> "\""

-- | Complete the JSON by closing it
finalizeMessage :: Text -> Text
finalizeMessage txt = txt <> "}"

-- | Subscribe handler to event bus
subscribeToEvents :: WebSocketHandler -> EventBusAdvanced -> Text -> IO ()
subscribeToEvents wsHandler bus routingKey =
  subscribeAdvanced bus routingKey $ \msg -> do
    broadcastEvent wsHandler msg
    return ()