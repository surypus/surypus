-- | Backup module - Database backup
module Infrastructure.Backup where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text
import Data.Time (UTCTime)

-- | Backup - Database backup
data Backup = Backup
  { bkId :: Int64,
    bkCode :: Text,
    bkPath :: Text,
    bkSize :: Int64,
    bkType :: BackupType,
    bkStatus :: BackupStatus,
    bkCreated :: UTCTime,
    bkFlags :: Int
  }
  deriving (Show, Eq)

data BackupType = BTFull | BTIncremental | BTConfig
  deriving (Show, Eq)

data BackupStatus = BSPending | BSInProgress | BSCompleted | BSFailed
  deriving (Show, Eq)

-- | Backup settings
data BackupSettings = BackupSettings
  { bsPath :: Text,
    bsRetentionDays :: Int,
    bsSchedule :: Text, -- cron
    bsCompress :: Bool,
    bsEncrypt :: Bool
  }
  deriving (Show, Eq)

-- | Validate backup path
validateBackupPath :: Backup -> Bool
validateBackupPath b = not (Data.Text.null (bkPath b))
