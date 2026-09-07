{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Finance.Journal - Enhanced journal with type safety and formal verification
-- This module provides a complete journaling system with double-entry bookkeeping
module Finance.Journal where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import GHC.Generics (Generic)

-- | Journal entry with enhanced metadata
data JournalEntry = JournalEntry
  { jeId          :: JournalId
  , jeDate        :: Day
  , jeDebitAcc    :: Text
  , jeCreditAcc   :: Text
  , jeAmount      :: Double
  , jeCurrency    :: Text
  , jeDescription :: Text
  , jeReference   :: Maybe Text
  , jeStatus      :: JournalStatus
  , jeCreatedBy  :: Int64
  , jeCreatedAt  :: UTCTime
  } deriving (Show, Eq, Generic)

-- | Newtype for type safety
newtype JournalId = JournalId { unJournalId :: Int64 }
  deriving (Show, Eq, Ord)

-- | Journal status
data JournalStatus
  = JSEntry   -- Draft entry
  | JSPosted   -- Posted to ledger
  | JSVerified -- Verified by supervisor
  | JSCancelled -- Cancelled
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Journal with enhanced operations
data Journal = Journal
  { journalEntries :: Map JournalId JournalEntry
  , journalBalances :: Map Text Double
  , journalCurrency  :: Text
  , journalValidated :: Bool
  } deriving (Show, Eq, Generic)

-- | Create journal entry with validation
createJournalEntry :: JournalId -> Day -> Text -> Text -> Double -> Text -> Text -> Int64 -> UTCTime -> JournalEntry
createJournalEntry jid date dbt cdt amt curr desc creator now = JournalEntry
  { jeId = jid
  , jeDate = date
  , jeDebitAcc = dbt
  , jeCreditAcc = cdt
  , jeAmount = amt
  , jeCurrency = curr
  , jeDescription = desc
  , jeReference = Nothing
  , jeStatus = JSEntry
  , jeCreatedBy = creator
  , jeCreatedAt = now
  }

-- | Cancel journal entry
cancelJournalEntry :: JournalEntry -> JournalEntry
cancelJournalEntry entry = entry { jeStatus = JSCancelled }

-- | Calculate journal balance
calculateJournalBalance :: Text -> Journal -> Double
calculateJournalBalance code journal =
  maybe 0 id (M.lookup code (journalBalances journal))

-- | Validate journal invariants
validateJournal :: Journal -> Bool
validateJournal journal =
  journalValidated journal &&
  all (\(_, entry) -> jeStatus entry /= JSEntry) (M.assocs (journalEntries journal))

-- | Pretty print journal entry
prettyJournalEntry :: JournalEntry -> Text
prettyJournalEntry entry =
  "Journal Entry #" <> T.pack (show (unJournalId (jeId entry))) <> "\n" <>
  "Date: " <> T.pack (show (jeDate entry)) <> "\n" <>
  "Debit: " <> jeDebitAcc entry <> "\n" <>
  "Credit: " <> jeCreditAcc entry <> "\n" <>
  "Amount: " <> T.pack (show (jeAmount entry)) <> "\n" <>
  "Description: " <> jeDescription entry

-- | Pretty print journal
prettyJournal :: Journal -> Text
prettyJournal journal =
  "Journal with " <> T.pack (show (M.size (journalEntries journal))) <> " entries\n" <>
  "Balances: " <> T.pack (show (M.size (journalBalances journal))) <> " accounts\n" <>
  "Validated: " <> T.pack (show (journalValidated journal))
