-- | Tax calculation module with single-point RatePercent → RateFraction conversion.
-- Arithmetic performed over Integer mantissa (Decimal internals), rounded half-up.
module Core.Tax (calcTaxInclusive, calcTaxExclusive) where

import Finance.Types

calcTaxInclusive :: RatePercent -> Money -> Money
calcTaxInclusive rate (Money amount) = Money (amount + calcVAT (Money amount) rate)
