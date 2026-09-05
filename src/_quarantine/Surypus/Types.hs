-- ═══════════════════════════════════════════════════════════════════════════
-- SURYPUS TYPES
-- Shared types for Surypus ERP (All-Haskell + Reflex)
-- ═══════════════════════════════════════════════════════════════════════════
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Surypus.Types
  ( module Surypus.Types.Bill,
    module Surypus.Types.Payment,
    module Surypus.Types.Stock,
    module Surypus.Types.Person,
    module Surypus.Types.Goods,
    module Surypus.Types.Auth,
    module Surypus.Types.Common,
  )
where

import Surypus.Types.Auth
import Surypus.Types.Bill
import Surypus.Types.Common
import Surypus.Types.Goods
import Surypus.Types.Payment
import Surypus.Types.Person
import Surypus.Types.Stock
