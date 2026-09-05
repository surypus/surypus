-- | Generic Service Layer for Surypus ERP
--
-- This module provides a unified service architecture that consolidates
-- all domain services into a single, type-safe framework.
--
-- = Design
--
-- The service layer uses a type-class based approach:
--
-- * 'Service' class defines the interface for all services
-- * 'ServiceM' monad provides context for service operations
-- * Each service is identified by a unique type tag
--
-- = Usage
--
-- @
-- data PersonService
-- data GoodsService
-- data BillService
--
-- instance Service PersonService Pool where
--   type ServiceKey PersonService = "person"
--   getPool = id
--
-- instance Service GoodsService Pool where
--   type ServiceKey GoodsService = "goods"
--   getPool = id
-- @
{-# LANGUAGE OverloadedStrings #-}
module Service.Service
  ( -- * Service Types
    ServiceKey,
    ServiceError   (..),
    ServiceM,

    -- * Service Class
    Service,

    -- * Service Builder
    mkService,

    -- * Common Service Types
    PoolService
  ) where

import Control.Monad.Except (ExceptT)
import Control.Monad.Reader (ReaderT)
import Data.Text (Text)

-- | Service identifier type
type ServiceKey = Text

-- | Stub type for Pool
type Pool = ()

-- | Settings service type
newtype SettingsService = SettingsService { unSettingsService :: Pool }

-- | Service-level errors
data ServiceError
  = ServiceNotFound ServiceKey
  | ServiceError Text
  deriving (Show, Eq)

-- | Service monad - Reader over service context, with error handling
type ServiceM = ReaderT Pool (ExceptT ServiceError IO)

-- | Service class
--
-- Defines the interface for all services in the system.
-- Each service must provide a unique key and access to its pool.
class Service s where
  -- type ServiceKey s :: ServiceKey
  getPool :: s -> Pool

-- | Create a service from a pool
mkService :: Pool -> PoolService s
mkService = PoolService

-- | Generic pool-based service
--
-- A simple service wrapper that holds a connection pool.
-- This can be used directly or wrapped by more specific service types.
newtype PoolService s = PoolService {unPoolService :: Pool}

instance Service (PoolService s) where
  -- type ServiceKey (PoolService s) = s
  getPool = unPoolService

instance Service SettingsService where
  getPool s = unSettingsService s
