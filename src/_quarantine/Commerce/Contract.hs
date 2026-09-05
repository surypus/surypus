-- | Contract module - Contracts management
module Commerce.Contract  where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Contract - Agreement with counterparty
data Contract = Contract
  { conId :: Int64,
    conCode :: Text,
    conKind :: ContractKind,
    conPartyId :: Int64,
    conStartDate :: Day,
    conEndDate :: Maybe Day,
    conAmount :: Double,
    conCurrencyId :: Int64,
    conStatus :: ContractStatus
  }
  deriving (Show, Eq)

data ContractKind = CKSupply | CKService | CKLoan | CKLease | CKOther
  deriving (Show, Eq)

data ContractStatus = CSDraft | CSActive | CSCompleted | CSCancelled
  deriving (Show, Eq)

-- | PaymentSchedule - Payment plan
data PaymentSchedule = PaymentSchedule
  { psId :: Int64,
    psContractId :: Int64,
    psDate :: Day,
    psAmount :: Double,
    psType :: PaymentType,
    psStatus :: PaymentStatus
  }
  deriving (Show, Eq)

data PaymentType = PTAdvance | PTIntermediate | PTFinal
  deriving (Show, Eq)

data PaymentStatus = PayPending | PayDone | PayOverdue
  deriving (Show, Eq)

-- | Check if contract is active
isContractActive :: Contract -> Day -> Bool
isContractActive c today =
  today >= conStartDate c
    && case conEndDate c of
      Nothing -> True
      Just ed -> today <= ed

-- | Calculate days until expiry
daysToExpiry :: Contract -> Day -> Maybe Int
daysToExpiry c today = case conEndDate c of
  Nothing -> Nothing
  Just ed -> Just (fromEnum ed - fromEnum today)
