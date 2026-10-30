-- | Tax calculation module with single-point RatePercent → RateFraction conversion.
-- Arithmetic performed over Integer mantissa (Decimal internals), rounded half-up.
module Core.Tax (calcTaxInclusive, calcTaxExclusive) where

import Finance.Types (Money (..), RatePercent (..), calcVAT)

calcTaxInclusive :: RatePercent -> Money -> Money
calcTaxInclusive rate (Money amount) =
  Money (amount + unMoney (calcVAT (Money amount) rate))

calcTaxExclusive :: RatePercent -> Money -> Money
calcTaxExclusive rate (Money amount) =
  Money (amount / (1 + unRatePercent rate / 100))
