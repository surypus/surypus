{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}

-- ═══════════════════════════════════════════════════════════════════════════
-- LEGACY TYPES
-- Deprecated types for backward compatibility during migration
-- These will be removed in version 0.2.0
-- ═══════════════════════════════════════════════════════════════════════════

module Surypus.Types.Legacy
  ( BillLine (..),
    Bill (..),
    PaymentStatus (..),
    Payment (..),
    DashboardData (..),
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

data BillLine = BillLine
  { blId :: Int64,
    blBillId :: Int64,
    blGoodId :: Int64,
    blQuantity :: Int,
    blPrice :: Double
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)

data Bill = Bill
  { billId :: Int64,
    number :: Text,
    status :: Text,
    amount :: Double,
    lines :: [BillLine],
    createdAt :: UTCTime
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)

data PaymentStatus = Pending | Confirmed | Settled
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)

data Payment = Payment
  { paymentId :: Int64,
    billId :: Int64,
    amount :: Double,
    status :: PaymentStatus,
    createdAt :: UTCTime
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)

data DashboardData = DashboardData
  { revenue :: Double,
    stockValue :: Double,
    pendingPayments :: Int
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)
