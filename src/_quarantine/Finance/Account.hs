{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Finance.Account - Chart of Accounts with rich types
-- This module defines the core account types with enhanced expressiveness
module Finance.Account where

import GHC.Generics (Generic)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import qualified Data.Text as T

-- | Enhanced Account classification with richer semantics
data AccountClass
  = AssetClass    -- Активы (01-19): Resources owned
  | LiabilityClass -- Пассивы (60-79): Obligations
  | EquityClass    -- Капитал (80-89): Owner's equity
  | RevenueClass  -- Доходы (90-99): Income streams
  | ExpenseClass -- Расходы (20-29, 44): Costs
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Account nature: how the account behaves in accounting
data AccountNature
  = DebitNature  -- Дебетовая (normal balance)
  | CreditNature -- Кредитовая (normal balance)
  deriving (Show, Eq, Enum)

-- | Account entry with enhanced type safety
data Account = Account
  { accountId      :: AccountId
  , accountCode     :: AccountCode
  , accountName     :: AccountName
  , accountClass    :: AccountClass
  , accountNature   :: AccountNature
  , parentAccountId :: Maybe AccountId
  , isGroupAccount  :: Bool
  , currencyAccount :: Maybe Text  -- CurrencyCode (simplified)
  , isActive       :: Bool
  , createdAt      :: Day
  , updatedAt      :: Maybe Day
  } deriving (Show, Eq, Generic)

-- | Newtypes for enhanced type safety
newtype AccountId = AccountId { unAccountId :: Int64 }
  deriving (Show, Eq, Ord)

newtype AccountCode = AccountCode { unAccountCode :: Text }
  deriving (Show, Eq, Ord)

newtype AccountName = AccountName { unAccountName :: Text }
  deriving (Show, Eq, Ord)

-- | Validate account code format (e.g. "1010", "50")
validateAccountCode :: AccountCode -> Maybe AccountCode
validateAccountCode code
  | T.null (unAccountCode code) = Nothing
  | T.all (\c -> c `elem` ("0123456789." :: String)) (unAccountCode code) = Just code
  | otherwise = Nothing

-- | Smart constructor for Account
createAccount :: Day -> AccountId -> AccountCode -> AccountName -> AccountClass -> Account
createAccount created aid code name cls = Account
  { accountId = aid
  , accountCode = code
  , accountName = name
  , accountClass = cls
  , accountNature = case cls of
      AssetClass -> DebitNature
      LiabilityClass -> CreditNature
      EquityClass -> CreditNature
      RevenueClass -> CreditNature
      ExpenseClass -> DebitNature
  , parentAccountId = Nothing
  , isGroupAccount = False
  , currencyAccount = Nothing
  , isActive = True
  , createdAt = created
  , updatedAt = Nothing
  }

-- | Check if account is asset class
isAssetAccount :: Account -> Bool
isAssetAccount acc = case accountClass acc of
  AssetClass -> True
  _ -> False

-- | Check if account is liability class
isLiabilityAccount :: Account -> Bool
isLiabilityAccount acc = case accountClass acc of
  LiabilityClass -> True
  _ -> False

-- | Pretty print account
prettyAccount :: Account -> Text
prettyAccount acc = unAccountCode (accountCode acc) <> " - " <> unAccountName (accountName acc)
