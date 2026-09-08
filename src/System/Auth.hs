-- | Auth module - Authentication and users
module System.Auth where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)

-- | User - System user
data User = User
  { uId :: Int64,
    uLogin :: Text,
    uName :: Text,
    uGroupId :: Int64,
    uFlags :: Int
  }
  deriving (Show, Eq)

-- | UserGroup - User group
data UserGroup = UserGroup
  { ugId :: Int64,
    ugName :: Text,
    ugRights :: Int -- Bitmask
  }
  deriving (Show, Eq)

-- | Session - User session
data Session = Session
  { sId :: Int64,
    sUserId :: Int64,
    sToken :: Text,
    sStartTime :: UTCTime,
    sExpireTime :: UTCTime
  }
  deriving (Show, Eq)

-- | Validate password strength (simple)
validatePassword :: Text -> Bool
validatePassword pwd = T.length pwd >= 6

-- | Check session expired
isSessionExpired :: Session -> UTCTime -> Bool
isSessionExpired s now = now > sExpireTime s
