{-# LANGUAGE OverloadedStrings #-}
-- | Inventory Service (Phase 1: stub)
module Service.InventoryService
  ( InventoryDocType(..)
  , InventoryDocStatus(..)
  , InventoryDocLine(..)
  , InventoryDoc(..)
  , StockMovement(..)
  , postInventoryDoc
  , generateMovements
  , calculateStockBalance
  , getStockSnapshot
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime)

-- | Inventory document type
data InventoryDocType
  = ReceiptDoc | IssueDoc | AdjustmentDoc | InventoryDocType
  deriving (Show, Eq)

-- | Inventory document status
data InventoryDocStatus
  = DocDraft | DocPosted | DocCancelled
  deriving (Show, Eq)

-- | Inventory document line
data InventoryDocLine = InventoryDocLine
  { inventoryDocLineItemId :: !Int64
  , inventoryDocLineQty :: !Double
  , inventoryDocLinePrice :: !Double
  } deriving (Show, Eq)

-- | Inventory document
data InventoryDoc = InventoryDoc
  { inventoryDocId :: !Int64
  , inventoryDocType :: !InventoryDocType
  , inventoryDocStatus :: !InventoryDocStatus
  , inventoryDocLines :: ![InventoryDocLine]
  } deriving (Show, Eq)

-- | Stock movement
data StockMovement = StockMovement
  { stockMovementItemId :: !Int64
  , stockMovementQty :: !Double
  } deriving (Show, Eq)

-- | Post inventory document (stub)
postInventoryDoc :: InventoryDoc -> IO (Either Text ())
postInventoryDoc _ = return $ Right ()

-- | Generate movements (stub)
generateMovements :: InventoryDoc -> [StockMovement]
generateMovements _ = []

-- | Calculate stock balance (stub)
calculateStockBalance :: Int64 -> IO Double
calculateStockBalance _ = return 0

-- | Get stock snapshot (stub)
getStockSnapshot :: IO [(Int64, Double)]
getStockSnapshot = return []
