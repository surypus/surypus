{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.OpKindEx - Operation kind extensions with type safety
-- Enhanced operation classification with formal verification
module Finance.OpKindEx where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import GHC.Generics (Generic)

-- | Enhanced operation kind with richer semantics
data OpKindEx
  = OKEInvoicePayment    -- Оплата счёта (invoice payment)
  | OKEPrepayment       -- Аванс (prepayment)
  | OKEAdvancePayment   -- Авансовый платёж (advance payment)
  | OKEReturn          -- Возврат (return)
  | OKEWriteOff        -- Списание (write-off)
  | OKETransfer        -- Перевод (transfer)
  | OKECurrencyExchange -- Обмен валюты (currency exchange)
  | OKECreditNote       -- Кредитовая нота (credit note)
  | OKEDeditNote        -- Дебетовая нота (debit note)
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Operation kind group for better classification
data OpKindGroup
  = PaymentGroup   -- Платежные операции
  | AdjustmentGroup -- Корректировки
  | TransferGroup    -- Переводы
  | FinancialGroup   -- Финансовые инструменты
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Get group for operation kind
opKindGroup :: OpKindEx -> OpKindGroup
opKindGroup OKEInvoicePayment = PaymentGroup
opKindGroup OKEPrepayment = PaymentGroup
opKindGroup OKEAdvancePayment = PaymentGroup
opKindGroup OKEReturn = PaymentGroup
opKindGroup OKEWriteOff = AdjustmentGroup
opKindGroup OKETransfer = TransferGroup
opKindGroup OKECurrencyExchange = TransferGroup
opKindGroup OKECreditNote = FinancialGroup
opKindGroup OKEDeditNote = FinancialGroup

-- | Check if operation involves payment
isPaymentOp :: OpKindEx -> Bool
isPaymentOp k = opKindGroup k == PaymentGroup

-- | Check if operation is adjustment
isAdjustmentOp :: OpKindEx -> Bool
isAdjustmentOp k = opKindGroup k == AdjustmentGroup

-- | Check if operation is transfer
isTransferOp :: OpKindEx -> Bool
isTransferOp k = opKindGroup k == TransferGroup

-- | Pretty print operation kind
prettyOpKindEx :: OpKindEx -> Text
prettyOpKindEx OKEInvoicePayment = "Invoice Payment"
prettyOpKindEx OKEPrepayment = "Prepayment"
prettyOpKindEx OKEAdvancePayment = "Advance Payment"
prettyOpKindEx OKEReturn = "Return"
prettyOpKindEx OKEWriteOff = "Write-Off"
prettyOpKindEx OKETransfer = "Transfer"
prettyOpKindEx OKECurrencyExchange = "Currency Exchange"
prettyOpKindEx OKECreditNote = "Credit Note"
prettyOpKindEx OKEDeditNote = "Debit Note"

-- | Pretty print operation group
prettyOpKindGroup :: OpKindGroup -> Text
prettyOpKindGroup PaymentGroup = "Payment Operations"
prettyOpKindGroup AdjustmentGroup = "Adjustment Operations"
prettyOpKindGroup TransferGroup = "Transfer Operations"
prettyOpKindGroup FinancialGroup = "Financial Instruments"
