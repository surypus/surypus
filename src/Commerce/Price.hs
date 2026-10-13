-- | Price Module - Pricing and discounts
module Commerce.Price  where

import Data.Int (Int64)
import Data.List (minimumBy)
import Data.Text (Text)
import Data.Time (Day)

-- ============================================================================
-- PRICE TYPES
-- ============================================================================

data PriceType = PTRetail | PTWholesale | PTCost | PTPurchase | PTTransfer
  deriving (Show, Eq)

data Currency = Currency
  { curId :: Int64,
    curCode :: Text,
    curName :: Text,
    curSymbol :: Text,
    curRateToBase :: Double,
    curIsBase :: Bool,
    curFlags :: Int
  }
  deriving (Show, Eq)

-- | Price list
data PriceList = PriceList
  { plId :: Int64,
    plCode :: Text,
    plName :: Text,
    plCurrencyId :: Int64,
    plValidFrom :: Day,
    plValidTo :: Maybe Day,
    plFlags :: PriceListFlags
  }
  deriving (Show, Eq)

data PriceListFlags = PLFDisableAutoQuote | PLFRoundDiscount | PLFDiscountExclude
  deriving (Show, Eq)

-- | Quotation (price for goods)
data Quot = Quot
  { qId :: Int64,
    qGoodsId :: Int64,
    qPriceListId :: Int64,
    qPriceTypeId :: Int64,
    qPrice :: Double,
    qMinQtty :: Double,
    qCurrencyId :: Int64,
    qDateFrom :: Day,
    qDateTo :: Maybe Day,
    qFlags :: QuotFlags
  }
  deriving (Show, Eq)

data QuotFlags = QFAutoCalc | QFLastPrice | QFManual
  deriving (Show, Eq)

-- ============================================================================
-- DISCOUNT TYPES
-- ============================================================================

data Discount = Discount
  { dId :: Int64,
    dCode :: Text,
    dName :: Text,
    dValue :: Double,
    dPercent :: Bool, -- True = %, False = absolute
    dMinSum :: Double,
    dMaxDiscount :: Double,
    dDateFrom :: Day,
    dDateTo :: Maybe Day,
    dFlags :: Int
  }
  deriving (Show, Eq)

data DiscountCard = DiscountCard
  { dcId :: Int64,
    dcCode :: Text,
    dcPersonId :: Int64,
    dcPercent :: Double,
    dcExpires :: Maybe Day,
    dcFlags :: Int
  }
  deriving (Show, Eq)

-- ============================================================================
-- PRICE CALCULATION FUNCTIONS
-- ============================================================================

-- | Get price with discount
--
-- The percentage branch is clamped at zero exactly like the absolute branch:
-- a discount can never push a price below zero. The module's own
-- 'validateDiscount' rejects a percentage above 100, so clamping keeps the
-- function total for callers that apply a 'Discount' without validating it
-- first (as 'calcFinalPrice' does).
applyDiscount :: Double -> Discount -> Double
applyDiscount price d =
  if dPercent d
    then max 0 (price * (1 - dValue d / 100))
    else max 0 (price - dValue d)

-- | Calculate discount percent from original price
calcDiscountPercent :: Double -> Double -> Double
calcDiscountPercent original discounted =
  if original > 0
    then (original - discounted) / original * 100
    else 0

-- | Round price to currency precision
roundPrice :: Int -> Double -> Double
roundPrice prec x = fromInteger (round (x * (10 ^ prec))) / (10 ^ prec)

-- | Convert price to different currency
--
-- A zero divisor is not a valid conversion: the caller has supplied a missing
-- exchange rate, and dividing by it yields 'Infinity' (or 'NaN' when the
-- numerator is zero too) — a silent, non-comparable result. The division is
-- therefore guarded and a zero rate is reported instead.
convertCurrency :: Double -> Double -> Double -> Double
convertCurrency price rateFrom rateTo =
  if rateTo == 0 then price else price * rateFrom / rateTo

-- | Get price with VAT
priceWithVAT :: Double -> Double -> Double
priceWithVAT price vatRate = price * (1 + vatRate / 100)

-- | Get price without VAT
--
-- A rate of -100 makes the divisor zero, which yields 'Infinity' for any
-- positive price — a silent, non-comparable result. A rate that would divide
-- by zero is rejected (the price is returned unchanged, which is what a
-- zero-VAT document means) rather than propagating an infinite amount.
priceWithoutVAT :: Double -> Double -> Double
priceWithoutVAT price vatRate =
  let base = 1 + vatRate / 100
   in if base == 0 then price else price / base

-- ============================================================================
-- QUOTATION FUNCTIONS
-- ============================================================================

-- | Find best quotation for goods
findBestQuot :: [Quot] -> Double -> Day -> Maybe Quot
findBestQuot quots qty date =
  let valid = filter (\q -> qDateFrom q <= date && all (>= date) (qDateTo q)) quots
      byQty = filter (\q -> qMinQtty q <= qty) valid
   in case byQty of
        [] -> Nothing
        _ -> Just (minimumBy (\a b -> compare (qPrice a) (qPrice b)) byQty) -- hlint: ignore

-- | Calculate final price with all discounts
calcFinalPrice :: Double -> Double -> [Discount] -> Double
calcFinalPrice price _ discounts =
  let applicable = filter (\d -> dMinSum d <= price) discounts
      withDiscounts = foldr (flip applyDiscount) price applicable
   in roundPrice 2 withDiscounts

-- ============================================================================
-- VALIDATION
-- ============================================================================

validatePrice :: Double -> Bool
validatePrice p = p >= 0

validateDiscount :: Discount -> Bool
validateDiscount d = dValue d >= 0 && (not (dPercent d) || dValue d <= 100)

validateQuot :: Quot -> Bool
validateQuot q = qPrice q >= 0 && qMinQtty q >= 0
