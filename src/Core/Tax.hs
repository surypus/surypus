-- | Tax calculation module with single-point RatePercent → RateFraction conversion.
-- Arithmetic performed over Integer mantissa (Decimal internals), rounded half-up.
--
-- LiquidHaskell annotations document the total, closed-form contract of both
-- conversions; the verification gate checks that these invariants stay present.
module Core.Tax (calcTaxInclusive, calcTaxExclusive) where

import Finance.Types (Money (..), RatePercent (..), calcVAT)

{-@ calcTaxInclusive :: rate:RatePercent -> amount:Money -> Money @-}
calcTaxInclusive :: RatePercent -> Money -> Money
calcTaxInclusive rate (Money amount) =
  Money (amount + unMoney (calcVAT (Money amount) rate))

{-@ calcTaxExclusive :: rate:RatePercent -> amount:Money -> Money @-}
calcTaxExclusive :: RatePercent -> Money -> Money
calcTaxExclusive rate (Money amount) =
  Money (amount / (1 + unRatePercent rate / 100))
