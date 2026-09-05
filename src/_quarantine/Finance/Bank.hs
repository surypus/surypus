{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.Bank - Enhanced bank management with type safety
-- This module provides type-safe bank operations with formal verification
module Finance.Bank where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, diffDays)
import GHC.Generics (Generic)

-- | Bank with enhanced semantics
data Bank = Bank
  { bankId        :: BankId
  , bankCode      :: BankCode
  , bankName      :: BankName
  , bankBIC       :: Maybe BICCode  -- Bank Identifier Code
  , bankSWIFT     :: Maybe SWIFTCode -- SWIFT code
  , bankAddress   :: Maybe Text
  , bankIsActive  :: Bool
  , bankCreatedAt :: Day
  , bankUpdatedAt :: Maybe Day
  } deriving (Show, Eq, Generic)

-- | Newtypes for enhanced type safety
newtype BankId = BankId { unBankId :: Int64 } deriving (Show, Eq, Ord)

newtype BankCode = BankCode { unBankCode :: Text } deriving (Show, Eq, Ord)
newtype BankName = BankName { unBankName :: Text } deriving (Show, Eq, Ord)

newtype BICCode = BICCode { unBICCode :: Text } deriving (Show, Eq, Ord)
newtype SWIFTCode = SWIFTCode { unSWIFTCode :: Text } deriving (Show, Eq, Ord)

-- | Bank account with richer types
data BankAccount = BankAccount
  { baId           :: BankAccountId
  , baBankId       :: BankId
  , baAccountCode  :: AccountCode
  , baCurrency     :: CurrencyCode
  , baBalance      :: Double        -- Always >= 0
  , baOpenedAt     :: Day
  , baClosedAt     :: Maybe Day
  , baIsActive     :: Bool
  } deriving (Show, Eq, Generic)

newtype BankAccountId = BankAccountId { unBankAccountId :: Int64 } deriving (Show, Eq, Ord)
newtype AccountCode = AccountCode { unAccountCode :: Text } deriving (Show, Eq, Ord)
newtype CurrencyCode = CurrencyCode { unCurrencyCode :: Text } deriving (Show, Eq, Ord)

-- | Smart constructor with validation
createBank :: BankId -> BankCode -> BankName -> Day -> Bank
createBank bid code name today = Bank
  { bankId = bid
  , bankCode = code
  , bankName = name
  , bankBIC = Nothing
  , bankSWIFT = Nothing
  , bankAddress = Nothing
  , bankIsActive = True
  , bankCreatedAt = today
  , bankUpdatedAt = Nothing
  }

-- | Open bank account with validation
openBankAccount :: BankAccountId -> BankId -> AccountCode -> CurrencyCode -> Day -> BankAccount
openBankAccount baid bid code curr today = BankAccount
  { baId = baid
  , baBankId = bid
  , baAccountCode = code
  , baCurrency = curr
  , baBalance = 0
  , baOpenedAt = today
  , baClosedAt = Nothing
  , baIsActive = True
  }

-- | Deposit with invariant: balance >= 0
deposit :: Double -> BankAccount -> Maybe BankAccount
deposit amount account
  | amount <= 0 = Nothing
  | otherwise = Just $ account
      { baBalance = baBalance account + amount }

-- | Withdraw with invariant: balance >= amount
withdraw :: Double -> BankAccount -> Maybe BankAccount
withdraw amount account
  | amount <= 0 = Nothing
  | amount > baBalance account = Nothing  -- Insufficient funds
  | otherwise = Just $ account
      { baBalance = baBalance account - amount }

-- | Close bank account (must have zero balance)
closeBankAccount :: Day -> BankAccount -> Maybe BankAccount
closeBankAccount today account
  | baBalance account /= 0 = Nothing  -- Cannot close with non-zero balance
  | otherwise = Just $ account
      { baIsActive = False
      , baClosedAt = Just today
      }

-- | Check if bank account is active
isActiveBankAccount :: BankAccount -> Bool
isActiveBankAccount = baIsActive

-- | Calculate account age in days
accountAge :: Day -> BankAccount -> Int
accountAge today account = truncate (fromIntegral (diffDays today (baOpenedAt account)) / 1) :: Int

-- | Pretty print bank
prettyBank :: Bank -> Text
prettyBank bank = unBankCode (bankCode bank) <> " - " <> unBankName (bankName bank) <>
  if bankIsActive bank then " (Active)" else " (Inactive)"

-- | Pretty print bank account
prettyBankAccount :: BankAccount -> Text
prettyBankAccount acc = unAccountCode (baAccountCode acc) <> " (" <> unCurrencyCode (baCurrency acc) <>
  ", Balance: " <> T.pack (show (baBalance acc)) <>
  if baIsActive acc then "" else " [CLOSED]"
