{-# LANGUAGE OverloadedStrings #-}
-- | MRP - Material Requirements Planning (Phase 1: stub)
module Production.MRP
  ( BOMLine(..)
  , MRPDemand(..)
  , calculateMRP
  , calculateMRPWithInventory
  , explodeBOM
  ) where

import Data.Int (Int64)
import Data.Text (Text)

-- | BOM line
data BOMLine = BOMLine
  { bomLineItemId :: !Int64
  , bomLineQty :: !Double
  } deriving (Show, Eq)

-- | MRP demand
data MRPDemand = MRPDemand
  { mrpDemandItemId :: !Int64
  , mrpDemandQty :: !Double
  } deriving (Show, Eq)

-- | Calculate MRP (stub)
calculateMRP :: [BOMLine] -> [MRPDemand] -> [MRPDemand]
calculateMRP _ demands = demands

-- | Calculate MRP with inventory (stub)
calculateMRPWithInventory :: [BOMLine] -> [MRPDemand] -> [MRPDemand] -> [MRPDemand]
calculateMRPWithInventory _ _ demands = demands

-- | Explode BOM (stub)
explodeBOM :: [BOMLine] -> Int64 -> [BOMLine]
explodeBOM lines _ = lines
