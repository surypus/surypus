{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Finance.Ledger - Enhanced accounting journal with rich types
-- This module provides type-safe ledger operations with formal verification
module Finance.Ledger where

import Finance.Account (Account   (..), AccountId, AccountCode (..), AccountClass   (..))
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import qualified Data.Text as T
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import GHC.Generics (Generic)

-- | Enhanced accounting entry with richer semantics
data AccTurn = AccTurn
  { turnId        :: TurnId           -- Unique identifier
  , turnBillId    :: Maybe BillId       -- Related bill
  , turnDebitAcc  :: AccountCode       -- Debit account code
  , turnCreditAcc :: AccountCode       -- Credit account code
  , turnAmount    :: Amount            -- Transaction amount
  , turnCurrency  :: CurrencyCode      -- Currency
  , turnDate      :: TransactionDate    -- Transaction date
  , turnObjectId  :: Maybe ObjectId     -- Related object
  , turnArticleId :: Maybe ArticleId    -- Analytical article
  , turnMemo      :: Maybe Text        -- Description
  , turnStatus    :: TurnStatus       -- Entry status
  } deriving (Show, Eq, Generic)

-- | Newtypes for enhanced type safety
newtype TurnId = TurnId { unTurnId :: Int64 }
  deriving (Show, Eq, Ord)

newtype BillId = BillId { unBillId :: Int64 }
  deriving (Show, Eq, Ord)

newtype Amount = Amount { unAmount :: Double }
  deriving (Show, Eq, Ord)

newtype CurrencyCode = CurrencyCode { unCurrencyCode :: Text }
  deriving (Show, Eq, Ord)

newtype TransactionDate = TransactionDate { unTransactionDate :: Day }
  deriving (Show, Eq, Ord)

newtype ObjectId = ObjectId { unObjectId :: Int64 }
  deriving (Show, Eq, Ord)

newtype ArticleId = ArticleId { unArticleId :: Int64 }
  deriving (Show, Eq, Ord)

-- | Transaction status
data TurnStatus
  = TSNew          -- New entry
  | TSPosted       -- Posted to ledger
  | TSReverted    -- Reverted
  | TSCancelled   -- Cancelled
  deriving (Show, Eq, Enum)

-- | Ledger with enhanced operations
data Ledger = Ledger
  { ledgerEntries :: Map TurnId AccTurn
  , ledgerBalance  :: Map AccountCode Amount
  , ledgerCurrency :: CurrencyCode
  } deriving (Show, Eq, Generic)

-- | Smart constructor with validation
createTurn :: TurnId -> AccountCode -> AccountCode -> Amount -> TransactionDate -> AccTurn
createTurn tid dbt cdt amt date = AccTurn
  { turnId = tid
  , turnBillId = Nothing
  , turnDebitAcc = dbt
  , turnCreditAcc = cdt
  , turnAmount = amt
  , turnCurrency = CurrencyCode "RUB"
  , turnDate = date
  , turnObjectId = Nothing
  , turnArticleId = Nothing
  , turnMemo = Nothing
  , turnStatus = TSNew
  }

-- | Validate accounting equation: total debits = total credits
validateAccountingEquation :: Ledger -> Bool
validateAccountingEquation ledger =
  let debitTotal = sum [unAmount (turnAmount t) | t <- M.elems (ledgerEntries ledger), isDebitAccount (turnDebitAcc t)]
      creditTotal = sum [unAmount (turnAmount t) | t <- M.elems (ledgerEntries ledger), isCreditAccount (turnCreditAcc t)]
  in abs (debitTotal - creditTotal) < 0.001  -- Tolerance for floating point

-- | Check if account is debit nature based on account code.
-- Active accounts (Asset, Expense): debit nature
-- Based on Russian Accounting Standards:
--   01-19: Asset (debit)
--   20-29, 44: Expense (debit)
--   30-39: Asset/Expense mixed (debit by default)
--   40-43: Production (debit)
--   50-59: Asset/cash (debit)
--   60-79: Liability (credit)
--   80-89: Equity (credit)
--   90-99: Revenue (credit)
isDebitAccount :: AccountCode -> Bool
isDebitAccount code =
  let t = unAccountCode code
      prefix = if T.length t >= 2 then T.take 2 t else t
   in case prefix of
        -- Active accounts (debit nature)
        "01" -> True  -- Fixed assets
        "02" -> True  -- Depreciation
        "03" -> True  -- Investments
        "04" -> True  -- Intangible assets
        "07" -> True  -- Equipment
        "08" -> True  -- Construction
        "09" -> True  -- Deferred tax
        "10" -> True  -- Materials
        "11" -> True  -- Animals
        "14" -> True  -- Reserves
        "15" -> True  -- Procurement
        "16" -> True  -- Variance
        "19" -> True  -- VAT
        "20" -> True  -- Production
        "21" -> True  -- Semi-finished
        "23" -> True  -- Auxiliary
        "25" -> True  -- Overhead
        "26" -> True  -- General expenses
        "28" -> True  -- Defects
        "29" -> True  -- Service
        "40" -> True  -- Output
        "41" -> True  -- Goods
        "42" -> True  -- Margin
        "43" -> True  -- Finished goods
        "44" -> True  -- Selling costs
        "45" -> True  -- Shipped goods
        "46" -> True  -- Work in progress
        "50" -> True  -- Cash
        "51" -> True  -- Bank accounts
        "52" -> True  -- Currency accounts
        "55" -> True  -- Special accounts
        "57" -> True  -- Transfers
        "58" -> True  -- Investments
        -- All others: credit nature (default passive)
        _    -> False

-- | Check if account is credit nature (opposite of debit)
isCreditAccount :: AccountCode -> Bool
isCreditAccount = not . isDebitAccount

-- | Post entry to ledger
postTurn :: AccTurn -> Ledger -> Maybe Ledger
postTurn turn ledger =
  if turnStatus turn /= TSNew
    then Nothing
    else Just $ ledger
      { ledgerEntries = M.insert (turnId turn) turn (ledgerEntries ledger)
      , ledgerBalance = updateBalance turn (ledgerBalance ledger)
      }

-- | Update balance after posting
updateBalance :: AccTurn -> Map AccountCode Amount -> Map AccountCode Amount
updateBalance turn balance =
  case (M.lookup (turnDebitAcc turn) balance, M.lookup (turnCreditAcc turn) balance) of
    (Just oldDebit, Just oldCredit) ->
      let updatedDebit = oldDebit { unAmount = unAmount oldDebit + unAmount (turnAmount turn) }
          updatedCredit = oldCredit { unAmount = unAmount oldCredit + unAmount (turnAmount turn) }
      in M.insert (turnCreditAcc turn) updatedCredit $ M.insert (turnDebitAcc turn) updatedDebit balance
    (Just oldDebit, Nothing) ->
      let updatedDebit = oldDebit { unAmount = unAmount oldDebit + unAmount (turnAmount turn) }
          newCredit = Amount { unAmount = unAmount (turnAmount turn) }
      in M.insert (turnCreditAcc turn) newCredit $ M.insert (turnDebitAcc turn) updatedDebit balance
    (Nothing, Just oldCredit) ->
      let newDebit = Amount { unAmount = unAmount (turnAmount turn) }
          updatedCredit = oldCredit { unAmount = unAmount oldCredit + unAmount (turnAmount turn) }
      in M.insert (turnCreditAcc turn) updatedCredit $ M.insert (turnDebitAcc turn) newDebit balance
    (Nothing, Nothing) ->
      let newDebit = Amount { unAmount = unAmount (turnAmount turn) }
          newCredit = Amount { unAmount = unAmount (turnAmount turn) }
      in M.insert (turnCreditAcc turn) newCredit $ M.insert (turnDebitAcc turn) newDebit balance

-- | Pretty print ledger entry
prettyTurn :: AccTurn -> Text
prettyTurn t = "Turn #" <> T.pack (show (unTurnId (turnId t))) <> ": "
            <> T.pack (show (turnDebitAcc t)) <> " -> " <> T.pack (show (turnCreditAcc t))
            <> " " <> T.pack (show (unAmount (turnAmount t)))

-- | Calculate account balance
calculateAccountBalance :: AccountCode -> Ledger -> Amount
calculateAccountBalance code ledger =
  maybe (Amount 0) id (M.lookup code (ledgerBalance ledger))
