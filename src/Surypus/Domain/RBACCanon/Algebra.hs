{-# LANGUAGE DeriveGeneric #-}
module Surypus.Domain.RBACCanon.Algebra where

import Surypus.Domain.RBACCanon.Types

-- Placeholder algebra: canonicalize a list of Canon values
canonicalizeAll :: [Canon] -> [Canon]
canonicalizeAll = id

-- A small helper: add a permission to a canon
addPerm :: Permission -> Canon -> Canon
addPerm p c = c { cPerms = p : cPerms c }
