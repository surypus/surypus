{-# LANGUAGE OverloadedStrings #-}
-- | Inventory WebSocket Broadcast (Phase 1: stub)
module Infrastructure.WebSocket.InventoryBroadcast (broadcastInventoryEvent) where

import Data.Text (Text)

-- | WebSocket handler (stub)
data WebSocketHandler = WebSocketHandler

-- | Inventory event (stub)
data InventoryEvent = InventoryEvent
  { inventoryEventItemId :: !Int
  , inventoryEventQty :: !Double
  } deriving (Show, Eq)

-- | Broadcast inventory event (stub)
broadcastInventoryEvent :: WebSocketHandler -> InventoryEvent -> IO ()
broadcastInventoryEvent _ _ = return ()

-- | Broadcast to room (stub)
broadcastToRoom :: WebSocketHandler -> Text -> Text -> IO ()
broadcastToRoom _ _ _ = return ()
