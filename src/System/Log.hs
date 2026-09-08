-- | Log module - System logging
module System.Log where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)

-- | LogEntry - Log entry
data LogEntry = LogEntry
  { leId :: Int64,
    leLevel :: LogLevel,
    leModule :: Text,
    leMessage :: Text,
    leTimestamp :: UTCTime,
    leUserId :: Maybe Int64
  }
  deriving (Show, Eq)

data LogLevel = LLDebug | LLInfo | LLWarning | LLError | LLCritical
  deriving (Show, Eq)

-- | LogConfig - Logging configuration
data LogConfig = LogConfig
  { lcLevel :: LogLevel,
    lcOutput :: LogOutput,
    lcFormat :: Text
  }
  deriving (Show, Eq)

data LogOutput = LOConsole | LOFile | LODatabase | LOSyslog
  deriving (Show, Eq)
