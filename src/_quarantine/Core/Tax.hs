{-# LANGUAGE StrictData #-}
{-# LANGUAGE BangPatterns #-}

{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple"        @-}

{-@ type ValidTaxRate = {v:Double | v >= 0.0 && v <= 1.0} @-}
{-@ type NonNegDouble = {v:Double | v >= 0.0} @-}

module Core.Tax
  ( TaxBracket(..)
  , applyTax
  , applyTaxInclusive
  , totalTax
  , mkTaxBracket
  ) where

import Data.Text (Text)

-- | Tax bracket with marginal rate
-- StrictData + BangPatterns for performance
data TaxBracket = TaxBracket
  { tbName :: !Text
  , tbRate :: !Double
  , tbThreshold :: !Double
  } deriving (Show, Eq)

-- | Smart constructor for TaxBracket
-- Returns Nothing if rate is invalid (not 0.0-1.0)
mkTaxBracket :: Text -> Double -> Double -> Maybe TaxBracket
mkTaxBracket name rate threshold
  | rate < 0.0 || rate > 1.0 = Nothing
  | threshold < 0.0 = Nothing
  | otherwise = Just TaxBracket
      { tbName = name
      , tbRate = rate
      , tbThreshold = threshold
      }

{-@ applyTax :: rate:ValidTaxRate -> base:NonNegDouble -> {v:NonNegDouble | v <= base} @-}
-- | Apply tax rate to base amount
-- Invariant: result >= 0 and result <= base
applyTax :: Double -> Double -> Double
applyTax !rate !base
  | rate < 0.0 || rate > 1.0 = 0.0
  | base < 0.0 = 0.0
  | otherwise = rate * base

{-@ applyTaxInclusive :: rate:ValidTaxRate -> gross:NonNegDouble -> {v:NonNegDouble | v <= gross} @-}
-- | Extract tax from gross (tax-inclusive) amount
-- Invariant: result >= 0 and result <= gross
applyTaxInclusive :: Double -> Double -> Double
applyTaxInclusive !rate !gross
  | rate < 0.0 || rate > 1.0 = 0.0
  | gross < 0.0 = 0.0
  | otherwise = gross * rate / (1.0 + rate)

{-@ totalTax :: brackets:[ValidTaxRate] -> base:NonNegDouble -> NonNegDouble @-}
-- | Calculate total tax for multiple brackets (e.g., VAT + excise)
-- Invariant: result >= 0
totalTax :: [Double] -> Double -> Double
totalTax !rates !base =
  sum [applyTax r base | r <- rates, r >= 0.0 && r <= 1.0]
