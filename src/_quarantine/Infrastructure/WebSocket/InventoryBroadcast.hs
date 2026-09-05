-- | Inventory WebSocket Broadcast - Translates inventory events to WS notifications
{-# LANGUAGE OverloadedStrings #-}
module Infrastructure.WebSocket.InventoryBroadcast (broadcastInventoryEvent) where

import Data.Aeson (encode)
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as TLE
import Surypus.WebSocket (WebSocketHandler, broadcastToRoom)
import Infrastructure.EventStore.Inventory (InventoryEvent   (..))

-- | Broadcast inventory event to "inventory" room and globally
broadcastInventoryEvent :: WebSocketHandler -> InventoryEvent -> IO ()
broadcastInventoryEvent handler event = do
  let msg = TL.toStrict $ TLE.decodeUtf8 $ encode event
  broadcastToRoom handler "inventory" msg
  broadcastToRoom handler "global" msg
