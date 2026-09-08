{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Surypus.Types.Auth
  ( LoginRequest (..),
    LoginResponse (..),
    RefreshRequest (..),
    RefreshResponse (..),
    UserInfo (..),
    UserRole (..),
    TokenPair (..),
    JwtClaims (..),
    Permission (..),
    ResourceAccess (..),
  )
where

import Data.Aeson (FromJSON (..), Options (..), ToJSON (..), defaultOptions, genericParseJSON, genericToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import Surypus.Types.Common (camelTo2)

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTHENTICATION TYPES
-- ═══════════════════════════════════════════════════════════════════════════

data LoginRequest = LoginRequest
  { reqUsername :: !Text,
    reqPassword :: !Text
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON LoginRequest where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

instance FromJSON LoginRequest where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

data LoginResponse = LoginResponse
  { respAccessToken :: !Text,
    respRefreshToken :: !Text,
    respUserId :: !Int64,
    respUserName :: !Text,
    respRole :: !Text,
    respExpiresIn :: !(Maybe Int)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON LoginResponse where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

instance FromJSON LoginResponse where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

data RefreshRequest = RefreshRequest
  { refreshToken :: !Text
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)

data RefreshResponse = RefreshResponse
  { newAccessToken :: !Text,
    newRefreshToken :: !Text,
    newExpiresIn :: !(Maybe Int)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON RefreshResponse where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

instance FromJSON RefreshResponse where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

data UserInfo = UserInfo
  { userId :: !Int64,
    userUsername :: !Text,
    userEmail :: !(Maybe Text),
    userFullName :: !(Maybe Text),
    userRoles :: ![UserRole],
    userPermissions :: ![Permission]
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON UserInfo where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

instance FromJSON UserInfo where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

data UserRole
  = RoleAdmin
  | RoleManager
  | RoleAccountant
  | RoleSales
  | RoleViewer
  deriving stock (Show, Eq, Generic, Enum, Bounded)

instance ToJSON UserRole

instance FromJSON UserRole

data TokenPair = TokenPair
  { tpAccessToken :: !Text,
    tpRefreshToken :: !Text,
    tpExpiresAt :: !UTCTime
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON TokenPair where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 2}

instance FromJSON TokenPair where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 2}

data JwtClaims = JwtClaims
  { jwtUserId :: !Int64,
    jwtUsername :: !Text,
    jwtRole :: !Text,
    jwtExp :: !Int64,
    jwtIat :: !Int64
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON JwtClaims where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

instance FromJSON JwtClaims where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

data Permission = Permission
  { permResource :: !Text,
    permAction :: !Text,
    permScope :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Permission where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

instance FromJSON Permission where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

data ResourceAccess = ResourceAccess
  { resResource :: !Text,
    resCanRead :: !Bool,
    resCanWrite :: !Bool,
    resCanDelete :: !Bool
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON ResourceAccess where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

instance FromJSON ResourceAccess where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}
