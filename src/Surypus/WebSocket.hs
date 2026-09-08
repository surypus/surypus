-- | WebSocket handler module for real-time notifications
-- Provides: (1) WebSocket connection handler, (2) Event broadcasting,
-- (3) Room-based subscriptions for entity types
{-# LANGUAGE OverloadedStrings #-}
module Surypus.WebSocket (
  WebSocketHandler,
  initWebSocketHandler,
  handleWebSocket,
  broadcastToRoom,
  broadcastGlobal,
  broadcastToInventoryRoom,
  broadcastInventoryEvent,
  broadcastToDashboardRoom,
  broadcastDashboardEvent
) where

import Control.Concurrent.STM
import Control.Exception (finally)
import Control.Monad (forever)
import Data.Aeson (Value, encode, object, (.=))
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString.Lazy as LBS
import qualified Network.WebSockets as WS

-- | WebSocket handler managing connections and rooms
-- Using Int keys since WS.Connection lacks Eq
data WebSocketHandler = WebSocketHandler
  { handlerConnections :: TVar (Map Text [(Int, WS.Connection)])
  -- ^ Connections by room with unique keys
  , handlerNextKey :: TVar Int
  -- ^ Next connection key for unique identification
  }

-- | Initialize WebSocket handler
initWebSocketHandler :: IO WebSocketHandler
initWebSocketHandler = do
  conns <- newTVarIO M.empty
  nextKey <- newTVarIO 0
  return $ WebSocketHandler conns nextKey

-- | Handle new WebSocket connection
handleWebSocket :: WebSocketHandler -> WS.Connection -> IO ()
handleWebSocket handler conn = do
  -- Get unique key for this connection
  key <- atomically $ do
    k <- readTVar (handlerNextKey handler)
    writeTVar (handlerNextKey handler) (k + 1)
    return k
    
  -- Join global room by default
  atomically $ do
    modifyTVar (handlerConnections handler) (M.insertWith (++) "global" [(key, conn)])

  -- Listen for messages or wait for disconnect
  WS.withPingThread conn 30 (pure ()) $
    (forever (WS.receiveData conn :: IO Text) `finally` cleanup key)
  where
    cleanup key = atomically $ do
      modifyTVar (handlerConnections handler) $ \conns ->
        M.map (filter ((/= key) . fst)) conns

-- | Broadcast to a specific room
broadcastToRoom :: WebSocketHandler -> Text -> Text -> IO ()
broadcastToRoom handler room msg = do
  conns <- readTVarIO (handlerConnections handler)
  let roomConns = M.findWithDefault [] room conns
  mapM_ (\(_, c) -> WS.sendTextData c msg) roomConns

-- | Broadcast to everyone
broadcastGlobal :: WebSocketHandler -> Text -> IO ()
broadcastGlobal handler = broadcastToRoom handler "global"

-- | Broadcast to inventory room specifically
broadcastToInventoryRoom :: WebSocketHandler -> Text -> IO ()
broadcastToInventoryRoom handler = broadcastToRoom handler "inventory"

-- | Broadcast inventory event as JSON
broadcastInventoryEvent :: WebSocketHandler -> Int64 -> Text -> Value -> IO ()
broadcastInventoryEvent handler goodsId eventType eventValue = do
  let eventObj = object
        [ "goodsId" .= goodsId
        , "eventType" .= eventType
        , "data" .= eventValue
        ]
  broadcastToInventoryRoom handler (TE.decodeUtf8 $ LBS.toStrict $ encode eventObj)

-- | Broadcast to dashboard room specifically
broadcastToDashboardRoom :: WebSocketHandler -> Text -> IO ()
broadcastToDashboardRoom handler = broadcastToRoom handler "dashboard"

-- | Broadcast dashboard KPI update as JSON
broadcastDashboardEvent :: WebSocketHandler -> Text -> Value -> IO ()
broadcastDashboardEvent handler eventType eventValue = do
  let eventObj = object
        [ "eventType" .= eventType
        , "data" .= eventValue
        ]
  broadcastToDashboardRoom handler (TE.decodeUtf8 $ LBS.toStrict $ encode eventObj)
