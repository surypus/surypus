-- | Redis Streams for domain events (US-3-3).
{-# LANGUAGE OverloadedStrings #-}
--
-- The PostgreSQL event store is the system of record; this is the fan-out path.
-- Publishing an event to a stream lets consumers (WebSocket, notifications,
-- search index) react without polling the database.
module Infrastructure.Redis.EventStream
  ( EventStream (..)
  , mkEventStream
  , defaultStreamName
  , publishEvent
  , readEvents
  , streamLength
  , encodeEvent
  , decodeEvent
  , esConn
  ) where

import Data.Aeson (FromJSON, ToJSON, Value, decodeStrict, encode)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Database.Redis as R

-- | A Redis Stream that carries domain events.
data EventStream = EventStream
  { esConn :: R.Connection
  , esStreamName :: Text
  }

-- | The stream used when the caller does not name one.
defaultStreamName :: Text
defaultStreamName = "surypus:events"

mkEventStream :: R.Connection -> Text -> EventStream
mkEventStream conn name = EventStream conn name

streamKey :: EventStream -> BS.ByteString
streamKey = TE.encodeUtf8 . esStreamName

-- | Append an event to the stream.
--
-- Redis assigns the entry id, so the caller only supplies the payload. The
-- @eventType@ is kept as a separate field so consumers can filter without
-- parsing the body.
publishEvent :: EventStream -> Text -> Value -> IO (Either Text ())
publishEvent stream eventType payload = do
  let fields =
        [ ("eventType", TE.encodeUtf8 eventType)
        , ("data", LBS.toStrict (encode payload))
        ]
  result <- R.runRedis (esConn stream) (R.xadd (streamKey stream) "*" fields)
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right _ -> Right ()

-- | Read up to @n@ entries from the stream, oldest first.
readEvents :: EventStream -> Integer -> IO (Either Text [(Text, Value)])
readEvents stream n = do
  result <- R.runRedis (esConn stream) (R.xrange (streamKey stream) "-" "+" (Just n))
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right records -> Right (mapMaybe decodeRecord records)
  where
    decodeRecord record = do
      let kvs = R.keyValues record
      rawType <- lookupField "eventType" kvs
      raw <- lookupField "data" kvs
      payload <- decodeStrict raw
      eventType <- either (const Nothing) Just (TE.decodeUtf8' rawType)
      pure (eventType, payload)

    lookupField name = lookup (TE.encodeUtf8 name)

-- | Number of entries currently in the stream.
streamLength :: EventStream -> IO (Either Text Integer)
streamLength stream = do
  result <- R.runRedis (esConn stream) (R.xlen (streamKey stream))
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right n -> Right n

-- | Round-trip helper used by the tests: the JSON survives the stream intact.
encodeEvent :: ToJSON a => a -> BS.ByteString
encodeEvent = LBS.toStrict . encode

-- | Inverse of 'encodeEvent'.
decodeEvent :: FromJSON a => BS.ByteString -> Maybe a
decodeEvent = decodeStrict
