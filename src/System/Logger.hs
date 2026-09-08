{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}

module System.Logger where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, readTVarIO, writeTVar, atomically)
import Data.Aeson (ToJSON(toJSON), object, (.=))
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)
import qualified System.IO ()

-- | Log levels
data LogLevel = Debug | Info | Warn | Error | Critical
  deriving (Show, Eq, Ord)

-- | Log entry
data LogEntry = LogEntry
  { logTimestamp :: UTCTime,
    logLevel :: LogLevel,
    logSource :: Text,
    logMessage :: Text,
    logContext :: [(Text, Text)]
  }

-- | Logger state
newtype Logger = Logger (TVar [LogEntry])

-- | Initialize logger
initLogger :: IO Logger
initLogger = Logger <$> newTVarIO []

-- | Log a message
writeLogMessage :: Logger -> LogLevel -> Text -> Text -> [(Text, Text)] -> IO ()
writeLogMessage (Logger var) level source msg context = do
  entry <- LogEntry <$> getCurrentTime <*> pure level <*> pure source <*> pure msg <*> pure context
  atomically $ do
    entries <- readTVar var
    writeTVar var (entry : entries)

-- | Get logs since a timestamp
getLogsSince :: Logger -> UTCTime -> IO [LogEntry]
getLogsSince (Logger var) sinceTime = do
  entries <- readTVarIO var
  return $ filter (\e -> logTimestamp e > sinceTime) entries

-- | Set log level filter
setLogLevel :: Logger -> LogLevel -> IO ()
setLogLevel _logger _newLevel = do
  -- Implementation for filtering
  return ()

-- | JSON serialization helper
instance ToJSON LogLevel where
  toJSON Debug = toJSON ("DEBUG" :: Text)
  toJSON Info = toJSON ("INFO" :: Text)
  toJSON Warn = toJSON ("WARN" :: Text)
  toJSON Error = toJSON ("ERROR" :: Text)
  toJSON Critical = toJSON ("CRITICAL" :: Text)

instance ToJSON LogEntry where
  toJSON LogEntry {..} =
    object
      [ "timestamp" .= logTimestamp,
        "level" .= logLevel,
        "source" .= logSource,
        "message" .= logMessage,
        "context" .= logContext
      ]
