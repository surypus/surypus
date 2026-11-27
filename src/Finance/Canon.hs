{-# LANGUAGE OverloadedStrings #-}
-- | Finance.Canon — pure calculations for Phase 4 (master data & inventory)
-- and Phase 5 (billing, payments and trial balance).
module Finance.Canon
  ( weightedAverageCost
  , cogs
  , trialBalance
  ) where

import Data.Text (Text)

-- | Weighted average unit cost from a list of @(quantity, unit cost)@
-- receipts. Zero/negative total quantity is rejected instead of producing
-- NaN or infinity.
weightedAverageCost :: [(Double, Double)] -> Either Text Double
weightedAverageCost receipts
  | totalQty <= 0 = Left "total quantity must be positive"
  | otherwise = Right (totalCost / totalQty)
  where
    totalQty = sum (map fst receipts)
    totalCost = sum [q * c | (q, c) <- receipts]

-- | Cost of goods sold for a shipment at the current weighted average cost.
cogs :: Double -> Double -> Double
cogs shippedQty averageCost = shippedQty * averageCost

-- | Trial balance totals. Debits and credits must match to the cent; the
-- comparison is done in integer kopecks to avoid floating-point drift.
trialBalance :: [(Text, Double, Double)] -> Either Text (Integer, Integer)
trialBalance rows
  | debitKopecks /= creditKopecks =
      Left "trial balance is not balanced"
  | otherwise = Right (debitKopecks, creditKopecks)
  where
    toKopecks x = round (x * 100) :: Integer
    debitKopecks = sum (map (toKopecks . (\(_, d, _) -> d)) rows)
    creditKopecks = sum (map (toKopecks . (\(_, _, c) -> c)) rows)
