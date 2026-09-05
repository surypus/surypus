{-# LANGUAGE DeriveGeneric #-}
module Surypus.Domain.RBACCanon.Domain where

import Surypus.Domain.RBACCanon.Types
import Surypus.Domain.RBACCanon.Model

-- Domain-level capability stub
canRunCanon :: Canon -> Bool
canRunCanon _ = True
