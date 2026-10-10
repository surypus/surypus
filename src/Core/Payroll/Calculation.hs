-- | Payroll calculation — income tax, social tax, vacation, sick leave, bonuses
-- Uses Data.Decimal for all monetary amounts (PYR-02)
{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple" @-}

{-@ type NonNegDec = {v:Decimal | v >= 0} @-}

module Core.Payroll.Calculation
  ( calcIncomeTax
  , calcSocialTax
  , calcNetSalaryFromGross
  , calcVacationDays
  , calcSickLeavePay
  , calcYearEndBonus
  , calcAdvanceAmount
  , calcMonthlyAdvance
  , calcTotalCompensation
  ) where

import Data.Decimal (Decimal)
import Data.Time (Day, diffDays)

-- | Calculate progressive income tax (НДФЛ)
-- Brackets: 13% ≤500k, 15% ≤3.5M, 18% ≤5M, 20% >5M
{-@ calcIncomeTax :: Decimal -> NonNegDec @-}
calcIncomeTax :: Decimal -> Decimal
calcIncomeTax salary
  | salary <= 0 = 0
  | salary <= 500000 = salary * 0.13
  | salary <= 3500000 = 65000 + (salary - 500000) * 0.15
  | salary <= 5000000 = 65000 + 450000 + (salary - 3500000) * 0.18
  | otherwise = 65000 + 450000 + 270000 + (salary - 5000000) * 0.20

-- | Calculate social tax (страховые взносы)
-- 30% up to cap of 876000, then 0% above cap
{-@ calcSocialTax :: Decimal -> NonNegDec @-}
calcSocialTax :: Decimal -> Decimal
calcSocialTax salary
  | salary <= 0 = 0
  | salary <= 876000 = salary * 0.30
  | otherwise = 876000 * 0.30

-- | Calculate net salary (gross - income tax - social tax)
{-@ calcNetSalaryFromGross :: gross:Decimal -> {v:NonNegDec | v <= gross} @-}
calcNetSalaryFromGross :: Decimal -> Decimal
calcNetSalaryFromGross gross
  | gross <= 0 = 0
  | otherwise  = gross - calcIncomeTax gross

-- | Calculate vacation days between two dates
calcVacationDays :: Day -> Day -> Int
calcVacationDays start end = fromIntegral (diffDays end start)

-- | Calculate sick leave pay
-- first3Days: if True, employer pays (60% of avg daily * min(3, days))
-- first3Days: if False, social insurance pays (80% of avg daily * remaining)
calcSickLeavePay :: Decimal -> Int -> Bool -> Decimal
calcSickLeavePay avgDaily totalDays first3Days
  | first3Days = avgDaily * 0.60 * fromIntegral (min 3 totalDays)
  | otherwise = avgDaily * 0.80 * fromIntegral (max 0 (totalDays - 3))

-- | Calculate year-end bonus (prorated by months worked)
-- Less than 3 months: no bonus
-- 3+ months: bonus * (months / 12)
calcYearEndBonus :: Int -> Decimal -> Decimal
calcYearEndBonus monthsWorked fullBonus
  | monthsWorked < 3 = 0
  | otherwise = fullBonus * fromIntegral monthsWorked / 12.0

-- | Calculate advance amount (percentage of base salary)
calcAdvanceAmount :: Decimal -> Decimal -> Decimal
calcAdvanceAmount base percentage = base * percentage / 100.0

-- | Calculate monthly advance (~40% of base)
calcMonthlyAdvance :: Decimal -> Decimal
calcMonthlyAdvance base = base * 0.40

-- | Calculate total compensation (base + additional payments)
calcTotalCompensation :: Decimal -> Decimal -> Decimal
calcTotalCompensation base additions = base + additions
