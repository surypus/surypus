-- | Alert module - Alerts
module System.Alert where

import Data.Int (Int64)
import Data.Time (Day)
import Data.Text (Text)

-- | Alert - Alert
data Alert = Alert
  { alrId :: Int64,
    alrType :: AlertType,
    alrMessage :: Text,
    alrDate :: Day,
    alrRead :: Bool
  }
  deriving (Show, Eq)

data AlertType = ATWarning | ATError | ATInfo | ATSuccess
  deriving (Show, Eq)

-- | Mark as read
markRead :: Alert -> Alert
markRead a = a {alrRead = True}
