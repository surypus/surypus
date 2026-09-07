-- | Currency Module - Currencies and exchange rates
module Finance.Currency where

import Data.Int (Int64)
import Data.Ratio ((%))
import Data.Text (Text)
import qualified Data.Text as T
import Test.QuickCheck

-- | Non-negative amount
{-@ type NonNeg = {v:Double | v >= 0} @-}

-- | Positive precision
{-@ type Precision = {v:Int | v >= 0 && v <= 6} @-}

-- | Exchange rate must be positive
{-@ type Rate = {v:Double | v > 0} @-}

-- | Currency
data Currency = Currency
  { curId :: Int64,
    curCode :: Text, -- ISO code (RUB, USD, EUR)
    curName :: Text,
    curSymbol :: Text,
    curRate :: Double, -- Rate to base currency
    curPrecision :: Int, -- Decimal places
    curFlags :: CurrencyFlags
  }
  deriving (Show, Eq)

-- | Currency flags
data CurrencyFlags = CurrencyFlags
  { cfBase :: Bool, -- Base currency
    cfCrypto :: Bool, -- Cryptocurrency
    cfInactive :: Bool -- Not in use
  }
  deriving (Show, Eq)

-- | Exchange rate
data ExchangeRate = ExchangeRate
  { erFromCurrency :: Int64,
    erToCurrency :: Int64,
    erRate :: Double,
    erDate :: Int -- Days since epoch
  }
  deriving (Show, Eq)

-- | Convert amount between currencies
-- = Invariant: result >= 0 if input >= 0
{-@ convertAmount :: Currency -> Currency -> NonNeg -> NonNeg @-}
convertAmount :: Currency -> Currency -> Double -> Double
convertAmount from to amount
  | curRate to == 0 = 0
  | otherwise = amount * curRate from / curRate to

--- | Round to currency precision
--- = Invariant: result is bounded by input ± 0.5 * 10^(-precision)
{-@ roundToCurrency :: Currency -> NonNeg -> NonNeg @-}
roundToCurrency :: Currency -> Double -> Double
roundToCurrency cur amount =
  let factor :: Integer
      factor = 10 ^ curPrecision cur
      amountR = toRational amount
      scaled = amountR * toRational factor
      roundedInt = round scaled :: Integer
      out = fromRational (roundedInt % factor)
   in out

-- | Format amount with currency symbol
-- = Invariant: result is non-empty
{-@ formatAmount :: Currency -> NonNeg -> {v:Text | len v > 0} @-}
formatAmount :: Currency -> Double -> Text
formatAmount cur amount =
  let rounded = roundToCurrency cur amount
   in T.cons (T.head (curSymbol cur)) (T.pack (show rounded))

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

-- | Property: Currency conversion is reversible (within precision)
prop_conversion_reversible :: Currency -> Currency -> Double -> Property
prop_conversion_reversible from to amount =
  let converted = convertAmount from to amount
      back = convertAmount to from converted
   in property (abs (back - amount) < 0.01)

-- | Property: Converting to same currency returns same amount
prop_convert_to_self :: Currency -> Double -> Property
prop_convert_to_self cur amount =
  let result = convertAmount cur cur amount
   in property (abs (result - amount) < 0.01)
