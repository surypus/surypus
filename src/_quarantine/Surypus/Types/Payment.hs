{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Surypus.Types.Payment
  ( Payment (..),
    PaymentStatus (..),
    PaymentInput (..),
    PaymentMethod (..),
    PaymentConfirmation (..),
  )
where

import Data.Aeson (FromJSON (..), Options (..), ToJSON (..), defaultOptions, genericParseJSON, genericToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import Surypus.Types.Common (camelTo2)

-- ═══════════════════════════════════════════════════════════════════════════
-- PAYMENT TYPES
-- ═══════════════════════════════════════════════════════════════════════════

data Payment = Payment
  { paymentId :: !Int64,
    paymentBillId :: !Int64,
    paymentAmount :: !Double,
    paymentStatus :: !PaymentStatus,
    paymentMethod :: !PaymentMethod,
    paymentCreatedAt :: !UTCTime,
    paymentConfirmedAt :: !(Maybe UTCTime),
    paymentExternalRef :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Payment where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 7}

instance FromJSON Payment where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 7}

data PaymentStatus
  = PaymentPending
  | PaymentConfirmed
  | PaymentSettled
  | PaymentFailed
  | PaymentRefunded
  deriving stock (Show, Eq, Generic)
  deriving anyclass (Enum, Bounded)

instance ToJSON PaymentStatus

instance FromJSON PaymentStatus

data PaymentMethod
  = Cash
  | Card
  | BankTransfer
  | OnlinePayment
  | Cryptocurrency
  deriving stock (Show, Eq, Generic, Enum, Bounded)

instance ToJSON PaymentMethod

instance FromJSON PaymentMethod

data PaymentInput = PaymentInput
  { pInputBillId :: !Int64,
    pInputAmount :: !Double,
    pInputMethod :: !PaymentMethod,
    pInputExternalRef :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON PaymentInput where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 6}

instance FromJSON PaymentInput where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 6}

data PaymentConfirmation = PaymentConfirmation
  { confPaymentId :: !Int64,
    confAmount :: !Double,
    confTimestamp :: !UTCTime,
    confSignature :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON PaymentConfirmation where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

instance FromJSON PaymentConfirmation where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}
