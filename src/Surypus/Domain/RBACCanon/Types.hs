{-# LANGUAGE DeriveGeneric #-}
module Surypus.Domain.RBACCanon.Types where

import Data.Text (Text)
import GHC.Generics (Generic)

type CanonName = Text

data Role = Admin | User | Auditor deriving (Eq, Show, Generic)
data Permission = Read | Write | Execute deriving (Eq, Show, Generic)

data Canon = Canon
  { cName  :: CanonName
  , cRoles :: [Role]
  , cPerms :: [Permission]
  } deriving (Eq, Show, Generic)

-- Simple smart constructor to ease tests and examples
mkCanon :: CanonName -> Canon
mkCanon name = Canon { cName = name, cRoles = [], cPerms = [] }
