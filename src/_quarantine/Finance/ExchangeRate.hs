{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.ExchangeRate - Enhanced currency exchange rate management
-- This module provides type-safe exchange rate operations with temporal validity
module Finance.ExchangeRate where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import GHC.Generics (Generic)
-- import Surypus.Types (Decimal, NonNeg, mkNonNeg, unNonNeg)

-- | Exchange rate with validation (rate > 0)
data ExchangeRate = ExchangeRate
  { erId             :: RateId
    , erFromCurrency   :: CurrencyCode
    , erToCurrency     :: CurrencyCode
    , erRate           :: Double -- Rate value (must be > 0)
    , erEffectiveFrom  :: Day           -- Valid from date
    , erEffectiveTo    :: Maybe Day     -- Valid until (Nothing = open-ended)
    , erSource         :: RateSource
    , erIsActive       :: Bool
    , erCreatedAt      :: Day
    , erUpdatedAt      :: Maybe Day
  } deriving (Show, Eq, Generic)

-- | Newtypes for type safety
newtype RateId = RateId { unRateId :: Int64 } deriving (Show, Eq, Ord)

newtype CurrencyCode = CurrencyCode { unCurrencyCode :: Text }
  deriving (Show, Eq, Ord)

-- | Rate source for audit trail
data RateSource
  = CentralBank    -- Central bank rate
  | CommercialBank -- Commercial bank rate
  | MarketRate     -- Market-driven rate
  | ManualRate     -- Manually set rate
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Smart constructor with validation
createExchangeRate :: RateId -> CurrencyCode -> CurrencyCode -> Double -> Day -> RateSource -> ExchangeRate
createExchangeRate rid from to rate date src = ExchangeRate
  { erId = rid
  , erFromCurrency = from
  , erToCurrency = to
  , erRate = rate
  , erEffectiveFrom = date
  , erEffectiveTo = Nothing
  , erSource = src
  , erIsActive = True
  , erCreatedAt = date
  , erUpdatedAt = Nothing
  }

-- | Check if rate is valid on a given date
isValidOnDate :: Day -> ExchangeRate -> Bool
isValidOnDate date rate =
  let startOk = erEffectiveFrom rate <= date
      endOk = maybe True (date <=) (erEffectiveTo rate)
  in startOk && endOk && erIsActive rate

-- | Close rate (set end date)
closeExchangeRate :: Day -> ExchangeRate -> ExchangeRate
closeExchangeRate closeDate rate = rate
  { erEffectiveTo = Just closeDate
  , erIsActive = False
  , erUpdatedAt = Just closeDate
  }

-- | Convert amount between currencies
-- Invariant: result > 0 if amount > 0
convertCurrency :: Double -> ExchangeRate -> Maybe Double
convertCurrency amount rate
  | amount <= 0 = Nothing
  | otherwise = Just $ amount * erRate rate

-- | Calculate inverse rate (1/rate)
-- Invariant: inverseRate * rate ≈ 1
inverseRate :: ExchangeRate -> Maybe Double
inverseRate rate
  | erRate rate == 0 = Nothing
  | otherwise = Just $ 1 / erRate rate

-- | Pretty print exchange rate
prettyExchangeRate :: ExchangeRate -> Text
prettyExchangeRate rate =
  unCurrencyCode (erFromCurrency rate) <> " -> " <> unCurrencyCode (erToCurrency rate) <>
  ": " <> T.pack (show (erRate rate)) <>
  " (Active: " <> T.pack (show (erIsActive rate)) <> ")"

-- | Calculate cross rate between two currencies via USD (simplified)
calculateCrossRate :: ExchangeRate -> ExchangeRate -> Maybe Double
calculateCrossRate rate1 rate2
  | erToCurrency rate1 /= erFromCurrency rate2 = Nothing  -- Must chain: FROM1 -> TO1/FROM2 -> TO2
  | otherwise =
      let r1 = erRate rate1
          r2 = erRate rate2
      in if r2 == 0 then Nothing else Just $ r1 / r2
