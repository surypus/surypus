-- | AccessControl module - Access control
module System.AccessControl where

import Data.Int (Int64)
import Data.Text (Text)

-- | Right - Access right
data Right = Right
  { rghId :: Int64,
    rghName :: Text,
    rghCode :: Text,
    rghCategory :: Text
  }
  deriving (Show, Eq)

-- | Role - User role
data Role = Role
  { roleId :: Int64,
    roleName :: Text,
    roleRights :: Text -- JSON array of right codes
  }
  deriving (Show, Eq)

-- | UserRole - User role assignment
data UserRole = UserRole
  { urUserId :: Int64,
    urRoleId :: Int64
  }
  deriving (Show, Eq)
