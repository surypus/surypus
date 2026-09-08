{-# LANGUAGE DeriveGeneric #-}
module Surypus.Domain.RBACCanon.API where

import Data.Text (Text)
import Surypus.Domain.RBACCanon.Types
import Surypus.Domain.RBACCanon.Domain

type APIResult = Either Text Canon

-- Simple API: fetch a Canon by name
getCanon :: CanonName -> APIResult
getCanon name = Right $ Canon { cName = name, cRoles = [], cPerms = [] }
