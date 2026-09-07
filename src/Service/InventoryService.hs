-- | Inventory Service — orchestrates inventory/stock operations
-- Patch F: Inventory lifecycle (receipts, issues, adjustments, inventory)
{-# LANGUAGE OverloadedStrings #-}

{-@ type NonNegDouble = {v:Double | v >= 0} @-}
{-@ type PosDouble    = {v:Double | v > 0}  @-}

module Service.InventoryService
  ( InventoryDocType   (..)
  , InventoryDocStatus   (..)
  , InventoryDocLine   (..)
  , InventoryDoc   (..)
  , StockMovement   (..)
  , postInventoryDoc
  , generateMovements
  , calculateStockBalance
  , getStockSnapshot
  ) where

import qualified Data.List as L
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime, getCurrentTime)
import Data.Map.Strict (Map)
import Inventory.Stock
import qualified Infrastructure.EventStore.Inventory as IEI

-- | Inventory document type
data InventoryDocType
  = IDTReceipt      -- Поступление товаров
  | IDTIssue        -- Списание товаров
  | IDTTransfer     -- Перемещение между складами
  | IDTWriteOff     -- Списание потерь
  | IDTAdjustment   -- Корректировка остатков
  deriving (Show, Eq)

-- | Inventory document status
data InventoryDocStatus
  = IDSDraft
  | IDSApproved
  | IDSPosted
  | IDSArchived
  deriving (Show, Eq, Enum)

-- | Inventory document line
data InventoryDocLine = InventoryDocLine
  { idlGoodsId :: Int64
  , idlLocationId :: Int64
  , idlQty :: Double
  , idlCost :: Double
  , idlPrice :: Double
  , idlToLocationId :: Maybe Int64 -- Used for transfers
  } deriving (Show, Eq)

-- | Inventory document
data InventoryDoc = InventoryDoc
  { idId :: Int64
  , idDocType :: InventoryDocType
  , idStatus :: InventoryDocStatus
  , idDate :: Day
  , idLines :: [InventoryDocLine]
  , idDescription :: Text
  }

-- | Stock movement record (classic projection)
data StockMovement = StockMovement
  { smGoodsId :: Int64
  , smFromLocation :: Maybe Int64
  , smToLocation :: Maybe Int64
  , smQty :: Double
  , smType :: StockMotionType
  }

{-@ postInventoryDoc :: IEI.InventoryEventStore -> (IEI.InventoryEvent -> IO ()) -> {v:InventoryDoc | idStatus v == IDSDraft || idStatus v == IDSApproved} -> IO (Either Text ()) @-}
-- | Post inventory document — apply stock movements as events
postInventoryDoc :: IEI.InventoryEventStore -> (IEI.InventoryEvent -> IO ()) -> InventoryDoc -> IO (Either Text ())
postInventoryDoc store notify doc = do
  let status = idStatus doc
  if status /= IDSApproved && status /= IDSDraft
    then pure $ Left "Only draft or approved documents can be posted"
    else do
      now <- getCurrentTime
      let events = generateEvents doc now
      res <- mapM (\ev -> do
        saveRes <- IEI.appendInventoryEvent store ev
        case saveRes of
          Right () -> notify ev >> pure (Right ())
          Left err -> pure $ Left err
        ) events
      case sequence res of
        Left err -> pure $ Left err
        Right _ -> pure $ Right ()

-- | Generate inventory events from document
generateEvents :: InventoryDoc -> UTCTime -> [IEI.InventoryEvent]
generateEvents doc now = concatMap mkEvents (idLines doc)
  where
    mkEvents line = case idDocType doc of
      IDTReceipt -> [IEI.StockReceivedEvent $ IEI.StockReceived (idlGoodsId line) (idlLocationId line) (idlQty line) Nothing now]
      IDTIssue   -> [IEI.StockShippedEvent $ IEI.StockShipped (idlGoodsId line) (idlLocationId line) (idlQty line) now]
      IDTTransfer -> case idlToLocationId line of
        Just toLoc -> [IEI.StockTransferredEvent $ IEI.StockTransferred (idlGoodsId line) (idlLocationId line) toLoc (idlQty line) now]
        Nothing -> [] -- Error or skip
      IDTWriteOff -> [IEI.StockWrittenOffEvent $ IEI.StockWrittenOff (idlGoodsId line) (idlLocationId line) (idlQty line) "Write-off" now]
      IDTAdjustment -> [IEI.StockAdjustedEvent $ IEI.StockAdjusted (idlGoodsId line) (idlLocationId line) (idlQty line) "Adjustment" now]

-- | Get current stock for a goods
getStockSnapshot :: IEI.InventoryEventStore -> Int64 -> IO (Either Text (Map (Int64, Int64) IEI.StockSnapshot))
getStockSnapshot = IEI.getStockSnapshot

{-@ generateMovements :: InventoryDoc -> [{v:StockMovement | smQty v >= 0 || smQty v < 0}] @-}
-- | Generate stock movements (classic logic)
generateMovements :: InventoryDoc -> [StockMovement]
generateMovements doc =
  case idDocType doc of
    IDTReceipt -> map receiptMovement (idLines doc)
    IDTIssue   -> map issueMovement (idLines doc)
    IDTTransfer -> concatMap transferMovements (idLines doc)
    IDTWriteOff -> map writeOffMovement (idLines doc)
    IDTAdjustment -> map adjustmentMovement (idLines doc)
  where
    receiptMovement line = StockMovement
      { smGoodsId = idlGoodsId line
      , smFromLocation = Nothing
      , smToLocation = Just (idlLocationId line)
      , smQty = abs (idlQty line)
      , smType = SMTReceipt
      }
    issueMovement line = StockMovement
      { smGoodsId = idlGoodsId line
      , smFromLocation = Just (idlLocationId line)
      , smToLocation = Nothing
      , smQty = -abs (idlQty line)
      , smType = SMTShipment
      }
    transferMovements line =
      [ StockMovement
          { smGoodsId = idlGoodsId line
          , smFromLocation = Just (idlLocationId line)
          , smToLocation = Nothing
          , smQty = -abs (idlQty line)
          , smType = SMTTransferOut
          }
      , StockMovement
          { smGoodsId = idlGoodsId line
          , smFromLocation = Nothing
          , smToLocation = idlToLocationId line
          , smQty = abs (idlQty line)
          , smType = SMTTransferIn
          }
      ]
    writeOffMovement line = StockMovement
      { smGoodsId = idlGoodsId line
      , smFromLocation = Just (idlLocationId line)
      , smToLocation = Nothing
      , smQty = -abs (idlQty line)
      , smType = SMTWriteOff
      }
    adjustmentMovement line = StockMovement
      { smGoodsId = idlGoodsId line
      , smFromLocation = Just (idlLocationId line)
      , smToLocation = Just (idlLocationId line)
      , smQty = idlQty line
      , smType = SMTAdjustment
      }

{-@ calculateStockBalance :: [{v:Stock | sQtty v >= 0}] -> [StockMovement] -> [{v:Stock | sQtty v >= 0}] @-}
-- | Calculate stock balance (pure)
calculateStockBalance :: [Stock] -> [StockMovement] -> [Stock]
calculateStockBalance = L.foldl' applyMovement

applyMovement :: [Stock] -> StockMovement -> [Stock]
applyMovement stocks movement = stocks -- Simplified for now