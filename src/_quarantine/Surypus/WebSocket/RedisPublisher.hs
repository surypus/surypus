{-# LANGUAGE OverloadedStrings #-}

module Surypus.WebSocket.RedisPublisher (publishEvent) where

import Control.Monad (void)
import qualified Database.Redis as R
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BSC
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

-- | Publish an event to the Redis channel for WebSocket broadcasting
publishEvent :: Text -> IO ()
publishEvent msg = do
  let connInfo = R.defaultConnectInfo { R.connectHost = "localhost", R.connectPort = R.PortNumber 6379 }
  conn <- R.checkedConnect connInfo
  let channel = TE.encodeUtf8 "surypus:events"
      message = BSC.pack $ T.unpack msg
  void $ R.runRedis conn $ R.publish channel message