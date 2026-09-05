{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Inventory.StockOps
  ( InvStock  (..)
  , MovementType  (..)
  , StockMovement  (..)
  , applyMovement
  , findStock
  , totalQuantityForGood
  , getAvailableQuantity
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)
import Data.Maybe (fromMaybe)

-- | Inventory stock record for a goods at a warehouse
data InvStock = InvStock
  { isId :: Int64
  , isGoodsId :: Int64
  , isWarehouseId :: Int64
  , isQty :: Double
  , isReserved :: Double
  } deriving (Show, Eq, Generic)

instance ToJSON InvStock
instance FromJSON InvStock

-- | Movement types
data MovementType = Receipt | Issue | Transfer | Adjustment
  deriving (Show, Eq, Generic)

instance ToJSON MovementType
instance FromJSON MovementType

-- | Stock movement
data StockMovement = StockMovement
  { smType :: MovementType
  , smGoodsId :: Int64
  , smFromWarehouse :: Maybe Int64
  , smToWarehouse :: Maybe Int64
  , smQty :: Double
  , smReason :: Maybe Text
  } deriving (Show, Eq, Generic)

instance ToJSON StockMovement
instance FromJSON StockMovement

-- | Get available quantity (qty - reserved)
getAvailableQuantity :: InvStock -> Double
getAvailableQuantity s = isQty s - isReserved s

-- | Find stock record by goods and warehouse
findStock :: [InvStock] -> Int64 -> Int64 -> Maybe InvStock
findStock stocks gid wid = case filter (\s -> isGoodsId s == gid && isWarehouseId s == wid) stocks of
  (s:_) -> Just s
  [] -> Nothing

-- | Update or insert stock record
upsertStock :: [InvStock] -> InvStock -> [InvStock]
upsertStock stocks rec =
  let others = filter (\s -> not (isId s == isId rec)) stocks
  in rec : filter (\s -> not (isGoodsId s == isGoodsId rec && isWarehouseId s == isWarehouseId rec)) others

-- | Generate new stock id
nextStockId :: [InvStock] -> Int64
nextStockId [] = 1
nextStockId ss = (maximum (map isId ss)) + 1

-- | Total quantity for a goods across all warehouses
totalQuantityForGood :: [InvStock] -> Int64 -> Double
totalQuantityForGood stocks gid = sum [isQty s | s <- stocks, isGoodsId s == gid]

-- | Apply a stock movement. Returns either an error message or updated stock list.
applyMovement :: [InvStock] -> StockMovement -> Either Text [InvStock]
applyMovement stocks mv
  | smQty mv <= 0 = Left "Quantity must be positive"
  | smType mv == Receipt = case smToWarehouse mv of
      Nothing -> Left "To-warehouse required for receipt"
      Just wid ->
        let gid = smGoodsId mv
            maybeRec = findStock stocks gid wid
            updated = case maybeRec of
              Just r -> r { isQty = isQty r + smQty mv }
              Nothing -> InvStock { isId = nextStockId stocks, isGoodsId = gid, isWarehouseId = wid, isQty = smQty mv, isReserved = 0 }
        in Right (upsertStock stocks updated)
  | smType mv == Issue = case smFromWarehouse mv of
      Nothing -> Left "From-warehouse required for issue"
      Just wid ->
        let gid = smGoodsId mv
            maybeRec = findStock stocks gid wid
        in case maybeRec of
          Nothing -> Left "Stock not found"
          Just r -> if getAvailableQuantity r >= smQty mv
                      then let updated = r { isQty = isQty r - smQty mv }
                           in Right (upsertStock stocks updated)
                      else Left "Insufficient available quantity"
  | smType mv == Transfer = case (smFromWarehouse mv, smToWarehouse mv) of
      (Just fromW, Just toW) ->
        let gid = smGoodsId mv
            mFrom = findStock stocks gid fromW
            mTo = findStock stocks gid toW
        in case mFrom of
          Nothing -> Left "Source stock not found"
          Just src -> if getAvailableQuantity src >= smQty mv
                        then let src' = src { isQty = isQty src - smQty mv }
                                 dst' = case mTo of
                                   Just d -> d { isQty = isQty d + smQty mv }
                                   Nothing -> InvStock { isId = nextStockId stocks, isGoodsId = gid, isWarehouseId = toW, isQty = smQty mv, isReserved = 0 }
                                 ss1 = upsertStock stocks src'
                                 ss2 = upsertStock ss1 dst'
                             in Right ss2
                        else Left "Insufficient available quantity at source"
      _ -> Left "Both from and to warehouses required for transfer"
  | smType mv == Adjustment = case (smFromWarehouse mv, smToWarehouse mv) of
      (Just wid, _) ->
        let gid = smGoodsId mv
            mRec = findStock stocks gid wid
        in case mRec of
          Nothing -> Right (stocks ++ [InvStock { isId = nextStockId stocks, isGoodsId = gid, isWarehouseId = wid, isQty = smQty mv, isReserved = 0 }])
          Just r -> let updated = r { isQty = smQty mv }
                    in Right (upsertStock stocks updated)
      _ -> Left "Warehouse required for adjustment"
  | otherwise = Left "Unknown movement type"
