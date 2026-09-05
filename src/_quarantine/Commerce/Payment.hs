-- | Payment module - Payments (corresponds to PaymentTbl in C<>)
module Commerce.Payment  where

import Data.Int (Int64)
import Data.Time (Day)
import Test.QuickCheck

-- ============================================================================
-- PAYMENT TYPES
-- ============================================================================

-- | Non-negative amount

{-@ type NonNeg = {v:Double | v >= 0} @-}

-- | Payment - Payment record
data Payment = Payment
  { payId :: Int64,
    payBillId :: Int64, -- Linked bill ID
    payDate :: Day,
    payAmount :: Double,
    payMethod :: PaymentMethod,
    payStatus :: PaymentStatus,
    payCardId :: Maybe Int64, -- Card ID for card payments
    payCashRegId :: Maybe Int64, -- Cash register ID
    payFlags :: Int
  }
  deriving (Show, Eq)

-- | Payment method - corresponds to PPPAYMT_*
data PaymentMethod
  = PMCash -- Cash (Наличные)
  | PMCard -- Card (Карта)
  | PMTransfer -- Bank transfer (Безналичные)
  | PMBonus -- Bonus points (Бонусы)
  | PMGiftCard -- Gift card (Подарочная карта)
  | PMCredit -- Credit (Кредит)
  deriving (Show, Eq, Enum)

-- | Payment status
data PaymentStatus
  = PSPending -- Pending (Ожидание)
  | PSCompleted -- Completed (Проведен)
  | PSFailed -- Failed (Ошибка)
  | PSRefunded -- Refunded (Возвращен)
  | PSCancelled -- Cancelled (Отменен)
  deriving (Show, Eq)

-- | Payment flags - corresponds to PAYMF_*
data PaymentFlags = PaymentFlags
  { pfRetrieved :: Bool, -- PAYMF_RETRIEVED
    pfOnline :: Bool, -- PAYMF_ONLINE
    pfPreauth :: Bool -- PAYMF_PREAUTH (pre-authorization)
  }
  deriving (Show, Eq)

-- ============================================================================
-- PAYMENT FUNCTIONS
-- ============================================================================

-- | Check if payment is completed

{-@ isCompleted :: Payment -> Bool @-}
isCompleted :: Payment -> Bool
isCompleted p = payStatus p == PSCompleted

-- | Check if payment can be refunded
-- = Invariant: can only refund completed positive payments

{-@ canRefund :: Payment -> Bool @-}
canRefund :: Payment -> Bool
canRefund p = payStatus p == PSCompleted && payAmount p > 0

-- | Calculate payment amount (ensure non-negative)
-- = Invariant: result >= 0

{-@ calcPaymentAmount :: Double -> NonNeg @-}
calcPaymentAmount :: Double -> Double
calcPaymentAmount = max 0

-- | Validate payment
-- = Invariant: amount must be positive

{-@ validatePayment :: Payment -> Bool @-}
validatePayment :: Payment -> Bool
validatePayment p = payAmount p > 0

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

-- | Property: Payment amount is non-negative
prop_payment_amount_positive :: Payment -> Property
prop_payment_amount_positive p =
  property (payAmount p >= 0)
