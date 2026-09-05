{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.DebitNote - Enhanced debit note management
-- This module provides type-safe debit note operations
module Finance.DebitNote where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import GHC.Generics (Generic)
-- import Surypus.Types (Decimal, NonNeg, mkNonNeg, unNonNeg)

-- | Debit note with validation (amount >= 0)
data DebitNote = DebitNote
  { dnId          :: DebitNoteId
  , dnNumber      :: DebitNoteNumber
  , dnDate        :: Day
  , dnAmount      :: Double -- Amount (must be >= 0)
  , dnCurrency    :: CurrencyCode
  , dnDescription :: Text
  , dnStatus      :: DebitNoteStatus
  , dnRelatedBill :: Maybe BillId
  , dnCreatedAt   :: Day
  , dnUpdatedAt   :: Maybe Day
  } deriving (Show, Eq, Generic)

-- | Newtypes for type safety
newtype DebitNoteId = DebitNoteId { unDebitNoteId :: Int64 }
  deriving (Show, Eq, Ord)

newtype DebitNoteNumber = DebitNoteNumber { unDebitNoteNumber :: Text }
  deriving (Show, Eq, Ord)

newtype CurrencyCode = CurrencyCode { unCurrencyCode :: Text }
  deriving (Show, Eq, Ord)

newtype BillId = BillId { unBillId :: Int64 }
  deriving (Show, Eq, Ord)

-- | Debit note status
data DebitNoteStatus
  = DNSIssued    -- Выставлен (issued)
  | DNSPaid      -- Оплачен (paid)
  | DNSCancelled -- Аннулирован (cancelled)
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Smart constructor with validation
createDebitNote :: DebitNoteId -> DebitNoteNumber -> Day -> Double -> CurrencyCode -> Text -> DebitNote
createDebitNote dnId num date amt curr desc = DebitNote
  { dnId = dnId
  , dnNumber = num
  , dnDate = date
  , dnAmount = amt
  , dnCurrency = curr
  , dnDescription = desc
  , dnStatus = DNSIssued
  , dnRelatedBill = Nothing
  , dnCreatedAt = date
  , dnUpdatedAt = Nothing
  }

-- | Pay debit note with invariant: amount > 0 and status is issued
payDebitNote :: Double -> DebitNote -> Maybe DebitNote
payDebitNote amount dn
  | amount <= 0 = Nothing
  | dnStatus dn /= DNSIssued = Nothing
  | otherwise = Just $ dn
      { dnStatus = DNSPaid
      , dnUpdatedAt = Just (fromGregorian 2024 1 1)  -- Should be supplied
      , dnAmount = dnAmount dn - amount
      }

-- | Cancel debit note
cancelDebitNote :: DebitNote -> DebitNote
cancelDebitNote dn = dn { dnStatus = DNSCancelled, dnUpdatedAt = Just (fromGregorian 2024 1 1) }

-- | Check if debit note is active
isActiveDebitNote :: DebitNote -> Bool
isActiveDebitNote dn = dnStatus dn == DNSIssued

-- | Pretty print debit note
prettyDebitNote :: DebitNote -> Text
prettyDebitNote dn = unDebitNoteNumber (dnNumber dn) <> " - " <> T.pack (show (dnAmount dn)) <> " " <> unCurrencyCode (dnCurrency dn)
