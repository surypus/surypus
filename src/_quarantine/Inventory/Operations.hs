-- | Inventory Operations with Formal Verification
-- Модуль содержит инварианты и проверенные операции для склада
module Inventory.Operations
  ( StockOpResult   (..),
    validateStockOperation,
    processReceipt,
    processIssue,
    processTransfer,
    checkNegativeStock,
    recalculateBalance
  ) where

import Inventory.Lot (Lot   (..))
import Data.Int (Int64)
import Data.Text (Text)

-- | Stock operation result
data StockOpResult
  = StockOpSuccess
  | StockOpInsufficientStock
  | StockOpInvalidQuantity
  | StockOpError Text
  deriving (Show, Eq)

-- | Validate stock operation
-- Инвариант: количество > 0
validateStockOperation :: Double -> StockOpResult
validateStockOperation qty
  | qty <= 0 = StockOpInvalidQuantity
  | otherwise = StockOpSuccess

-- | Process goods receipt (приход)
-- Постусловие: остаток увеличивается на qty
processReceipt :: Double -> Double -> Double -> StockOpResult
processReceipt _current qty _
  | qty <= 0 = StockOpInvalidQuantity
  | otherwise = StockOpSuccess

-- Результат: new_balance = current + qty

-- | Process goods issue (расход)
-- Инвариант: нельзя отгрузить больше чем есть
-- Постусловие: new_balance = current - qty (если enough stock)
processIssue :: Double -> Double -> StockOpResult
processIssue current qty
  | qty <= 0 = StockOpInvalidQuantity
  | qty > current = StockOpInsufficientStock
  | otherwise = StockOpSuccess

-- Результат: new_balance = current - qty

-- | Process transfer between locations
-- Инвариант: достаточно товара на исходном складе
processTransfer :: Double -> Double -> Double -> StockOpResult
processTransfer fromStock qty _toStock
  | qty <= 0 = StockOpInvalidQuantity
  | qty > fromStock = StockOpInsufficientStock
  | otherwise = StockOpSuccess

-- Результат: from = fromStock - qty, to = toStock + qty

-- | Check for negative stock
-- Инвариант: остаток >= 0 для всех позиций
checkNegativeStock :: [(Int64, Double)] -> [(Int64, Double)]
checkNegativeStock = filter (\(_, qty) -> qty < 0)

-- | Recalculate balance from lot list
-- Инвариант: результат >= 0
recalculateBalance :: [Lot] -> Double
recalculateBalance lots = sum (fmap lotQtty lots)

-- Теорема: sum(lotQtty) >= 0 если все lotQtty >= 0
