-- | WarehouseOps module - Warehouse operations
module Inventory.WarehouseOps where

import Data.Int (Int64)

-- | WarehouseOps - Warehouse operation
data WarehouseOps = WarehouseOps
  { woId :: Int64,
    woType :: WarehouseOpType,
    woGoodsId :: Int64,
    woFromLocId :: Maybe Int64,
    woToLocId :: Maybe Int64,
    woQtty :: Double,
    woStatus :: OpStatus
  }
  deriving (Show, Eq)

data WarehouseOpType = WOTPick | WOTPack | WOTShip | WOTReceive | WOTReturns
  deriving (Show, Eq)

data OpStatus = OPSPending | OPSInProgress | OPSCompleted | OPSCancelled
  deriving (Show, Eq)
