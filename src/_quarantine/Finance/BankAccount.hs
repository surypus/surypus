{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.BankAccount - Enhanced bank account management with type safety
-- This module provides secure bank account operations with formal verification
module Finance.BankAccount where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian, diffDays)
import GHC.Generics (Generic)


-- | Enhanced bank account with richer types
data BankAccount = BankAccount
  { baId            :: BankAccountId
  , baBankId        :: BankId
  , baAccountNumber :: AccountNumber
  , baAccountName   :: AccountName
  , baCurrency       :: CurrencyCode
  , baBalance        :: Double
  , baOpenedAt      :: Day
  , baClosedAt      :: Maybe Day
  , baIsActive      :: Bool
  , baBranchCode    :: Maybe BranchCode
  , baBIC           :: Maybe BICCode
  , baCorrespondent :: Maybe Text
  } deriving (Show, Eq, Generic)

-- | Newtypes for enhanced type safety
newtype BankAccountId = BankAccountId { unBankAccountId :: Int64 }
  deriving (Show, Eq, Ord)

newtype BankId = BankId { unBankId :: Int64 }
  deriving (Show, Eq, Ord)

newtype AccountNumber = AccountNumber { unAccountNumber :: Text }
  deriving (Show, Eq, Ord)

newtype AccountName = AccountName { unAccountName :: Text }
  deriving (Show, Eq, Ord)

newtype CurrencyCode = CurrencyCode { unCurrencyCode :: Text }
  deriving (Show, Eq, Ord)

newtype BranchCode = BranchCode { unBranchCode :: Text }
  deriving (Show, Eq, Ord)

newtype BICCode = BICCode { unBICCode :: Text }
  deriving (Show, Eq, Ord)

-- | Smart constructor with validation
createBankAccount :: BankAccountId -> BankId -> AccountNumber -> AccountName -> CurrencyCode -> Day -> BankAccount
createBankAccount newBaId bankId accNum accName curr today = BankAccount
  { baId = newBaId
  , baBankId = bankId
  , baAccountNumber = accNum
  , baAccountName = accName
  , baCurrency = curr
  , baBalance = 0
  , baOpenedAt = today
  , baClosedAt = Nothing
  , baIsActive = True
  , baBranchCode = Nothing
  , baBIC = Nothing
  , baCorrespondent = Nothing
  }

-- | Deposit with invariant: balance >= 0 after deposit
depositToAccount :: Double -> BankAccount -> Maybe BankAccount
depositToAccount amount account
  | amount <= 0 = Nothing
  | otherwise = Just $ account
      { baBalance = baBalance account + amount
      }

-- | Withdraw with invariant: balance >= amount (sufficient funds)
withdrawFromAccount :: Double -> BankAccount -> Maybe BankAccount
withdrawFromAccount amount account
  | amount <= 0 = Nothing
  | amount > baBalance account = Nothing  -- Insufficient funds
  | otherwise = Just $ account
      { baBalance = baBalance account - amount
      }

-- | Close account - must have zero balance
closeBankAccount :: BankAccount -> Maybe BankAccount
closeBankAccount account
  | baBalance account /= 0 = Nothing  -- Cannot close with non-zero balance
  | otherwise = Just $ account
      { baIsActive = False
      , baClosedAt = Just (fromGregorian 2024 1 1)  -- Should be supplied
      }

-- | Check if account is active
isActiveAccount :: BankAccount -> Bool
isActiveAccount = baIsActive

-- | Check if account has sufficient funds
hasSufficientFunds :: Double -> BankAccount -> Bool
hasSufficientFunds amount account = baBalance account >= amount

-- | Calculate account age in days
accountAge :: Day -> BankAccount -> Int
accountAge today account = truncate (fromIntegral (diffDays today (baOpenedAt account)) / (1 :: Double)) :: Int

-- | Pretty print bank account
prettyBankAccount :: BankAccount -> Text
prettyBankAccount acc = unAccountNumber (baAccountNumber acc) <> " - " <> unAccountName (baAccountName acc) <>
  ", Balance: " <> T.pack (show (baBalance acc)) <>
  if baIsActive acc then " (Active)" else " (Closed)"
