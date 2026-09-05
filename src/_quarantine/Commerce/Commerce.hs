-- | Commerce module - Retail operations
module Commerce.Commerce  where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime)

-- | CashNode - Cash register
data CashNode = CashNode
  { cnId :: Int64,
    cnCode :: Text,
    cnName :: Text,
    cnLocationId :: Int64,
    cnFlags :: Int
  }
  deriving (Show, Eq)

-- | CSession - Cash session
data CSession = CSession
  { csId :: Int64,
    csCashNodeId :: Int64,
    csUserId :: Int64,
    csStartTime :: UTCTime,
    csEndTime :: Maybe UTCTime,
    csStartSum :: Double,
    csFlags :: Int
  }
  deriving (Show, Eq)

-- | CCheck - Cash receipt
data CCheck = CCheck
  { ccId :: Int64,
    ccSessionId :: Int64,
    ccCode :: Text,
    ccDate :: Day,
    ccTime :: UTCTime,
    ccAmount :: Double,
    ccDiscount :: Double,
    ccFlags :: Int
  }
  deriving (Show, Eq)

-- | SCard - Loyalty card
data SCard = SCard
  { scId :: Int64,
    scCode :: Text,
    scPersonId :: Int64,
    scSeriesId :: Int64,
    scBalance :: Double,
    scFlags :: Int
  }
  deriving (Show, Eq)

-- | Validate cash session: end time after start
validateSession :: CSession -> Bool
validateSession cs = case csEndTime cs of
  Nothing -> True
  Just et -> et > csStartTime cs
