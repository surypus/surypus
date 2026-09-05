{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Production.WorkOrder
  ( WorkOrder   (..),
    WorkOrderStatus   (..),
    createWorkOrder
  ) where

import Data.Int (Int64)
import Data.Time (Day)

data WorkOrderStatus = WO_New | WO_InProgress | WO_Completed deriving (Eq, Show)

data WorkOrder = WorkOrder
  { woId :: Int64,
    woCardId :: Int64,
    woStatus :: WorkOrderStatus,
    woDueDate :: Day
  }
  deriving (Show, Eq)

createWorkOrder :: Int64 -> Int64 -> Day -> WorkOrder
createWorkOrder newWoId cardId due = WorkOrder newWoId cardId WO_New due
