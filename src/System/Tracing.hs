{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
module System.Tracing where

import Data.Text (Text, pack)
import Data.Time.Clock (UTCTime, getCurrentTime)
import qualified Data.UUID as UUID
import Data.UUID.V4 (nextRandom)
import Control.Exception (try, SomeException)
import Data.Aeson (ToJSON(..), Value, object, (.=))

-- | Trace context for distributed tracing
data TraceContext = TraceContext
  { traceId :: Text,
    spanId :: Text,
    parentSpanId :: Maybe Text,
    sampled :: Bool
  }

-- | Initialize trace context
initTraceContext :: IO TraceContext
initTraceContext = do
  tid <- UUID.toText <$> nextRandom
  sid <- UUID.toText <$> nextRandom
  pure $ TraceContext tid sid Nothing True

-- | Start a new span
data Span = Span
  { spanId :: Text,
    spanName :: Text,
    spanStartTime :: UTCTime,
    spanTags :: [(Text, Text)],
    spanLogs :: [(UTCTime, Text)],
    spanChildSpans :: [Span]
  }
  deriving (Show)

-- | Start timing a span
startSpan :: Text -> IO Span
startSpan name = do
  now <- getCurrentTime
  tid <- UUID.toText <$> nextRandom
  pure $ Span tid name now [] [] []

-- | Add tag to span
addSpanTag :: Span -> Text -> Text -> Span
addSpanTag span key value = span { spanTags = (key, value) : spanTags span }

-- | Add log to span
addSpanLog :: Span -> Text -> IO Span
addSpanLog span msg = do
  now <- getCurrentTime
  pure $ span { spanLogs = (now, msg) : spanLogs span }

-- | Finish span
endSpan :: Span -> IO ()
endSpan _ = pure ()

-- | Traced result - either success or failure
data Traced a = Traced
  { tracedValue :: Either SomeException a
  , tracedSpan :: Span
  } deriving (Show)

-- | Trace an operation with automatic span management
-- Returns Traced wrapper with Either result instead of crashing on error
traceOperation :: Text -> IO a -> IO (Traced a)
traceOperation operation action = do
  span <- startSpan operation
  result <- try @SomeException action
  case result of
    Right val -> do
      endSpan span
      return $ Traced (Right val) span
    Left err -> do
      loggedSpan <- addSpanLog span ("Error: " <> pack (show err))
      endSpan loggedSpan
      return $ Traced (Left err) loggedSpan

-- | Create trace context JSON
instance ToJSON TraceContext where
  toJSON TraceContext {..} = object
    [ "trace_id" .= traceId
    , "span_id" .= spanId
    , "parent_span_id" .= parentSpanId
    , "sampled" .= sampled
    ]

-- | Create span JSON
instance ToJSON Span where
  toJSON Span {..} = object
    [ "span_id" .= spanId
    , "name" .= spanName
    , "start_time" .= spanStartTime
    , "tags" .= spanTags
    , "logs" .= spanLogs
    ]
