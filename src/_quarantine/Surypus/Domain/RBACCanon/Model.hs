{-# LANGUAGE DeriveGeneric #-}
module Surypus.Domain.RBACCanon.Model where

import GHC.Generics (Generic)
import Surypus.Domain.RBACCanon.Types

-- Lightweight domain model for RBAC Canonicalization
data CanonicalRBAC = CanonicalRBAC
  { crName  :: CanonName
  , crRoles :: [Role]
  , crPerms :: [Permission]
  } deriving (Eq, Show, Generic)

mkCanonicalRBAC :: CanonName -> CanonicalRBAC
mkCanonicalRBAC name = CanonicalRBAC { crName = name, crRoles = [], crPerms = [] }
