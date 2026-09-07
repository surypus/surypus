{-| Settings service for organization and tenant configuration
-
This service provides organization and user settings that can be
loaded dynamically from the API instead of being hardcoded in the UI.
-}
module Service.Settings where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Map.Strict as Map
import Data.Time (UTCTime)

import Service.Service

-- | Settings service for organization and tenant configuration
data SettingsService = SettingsService
  { tenants      :: Map.Map Int64 Tenant
  , users        :: Map.Map Int64 User
  , currentTenant :: Maybe Tenant
  , currentUser   :: Maybe User
  , lastUpdated   :: UTCTime
  } deriving (Show, Eq)

-- | Tenant information
--
-- This corresponds to the current organization/unit in the system
data Tenant = Tenant
  { tenantId      :: Int64
  , tenantName    :: Text
  , tenantINN     :: Text
  , tenantKPP     :: Text
  , tenantOGRN    :: Text
  , tenantAddress :: Text
  , tenantPhone   :: Text
  , tenantEmail   :: Text
  } deriving (Show, Eq)

-- | User information
--
-- This corresponds to user account information
data User = User
  { userId        :: Int64
  , userName      :: Text
  , userEmail     :: Text
  , userRole      :: Text
  , userStatus    :: Text
  , userPermissions :: [Text]
  } deriving (Show, Eq)

-- | Empty settings service
emptySettingsService :: UTCTime -> SettingsService
emptySettingsService now =
  SettingsService
    { tenants      = Map.empty
    , users        = Map.empty
    , currentTenant = Nothing
    , currentUser   = Nothing
    , lastUpdated   = now
    }

-- | Add a tenant to the service
declareTenant :: SettingsService -> Tenant -> SettingsService
declareTenant service tenant =
  service { tenants = Map.insert (tenantId tenant) tenant (tenants service) }

-- | Add a user to the service
declareUser :: SettingsService -> User -> SettingsService
declareUser service user =
  service { users = Map.insert (userId user) user (users service) }

-- | Set the current tenant (organization)
setCurrentTenant :: SettingsService -> Int64 -> Maybe SettingsService
setCurrentTenant service tenantId =
  case Map.lookup tenantId (tenants service) of
    Just tenant -> Just (service { currentTenant = Just tenant })
    Nothing     -> Nothing

-- | Set the current user
updateCurrentUser :: SettingsService -> Int64 -> Maybe SettingsService
updateCurrentUser service userId =
  case Map.lookup userId (users service) of
    Just user -> Just (service { currentUser = Just user })
    Nothing   -> Nothing

-- | Get current organization name
getOrganizationName :: SettingsService -> Maybe Text
getOrganizationName = fmap tenantName . currentTenant

-- | Get current user name
getUserName :: SettingsService -> Maybe Text
getUserName = fmap userName . currentUser

-- | Get current user email
getUserEmail :: SettingsService -> Maybe Text
getUserEmail = fmap userEmail . currentUser

-- | Get current user role
getUserRole :: SettingsService -> Maybe Text
getUserRole = fmap userRole . currentUser

-- | Get company details (INN, KPP, OGRN)
getCompanyDetails :: SettingsService -> Maybe (Text, Text, Text)
getCompanyDetails service =
  case currentTenant service of
    Just tenant -> Just (tenantINN tenant, tenantKPP tenant, tenantOGRN tenant)
    Nothing     -> Nothing

-- | Update settings and return new state
refreshSettings :: UTCTime -> SettingsService -> SettingsService
refreshSettings now service =
  service { lastUpdated = now }
