-- | Accounting Service - Orchestrates event-sourced accounting operations
-- Implements double-entry bookkeeping with event sourcing for audit trail
{-# LANGUAGE OverloadedStrings #-}
module Core.Services.Accounting
  ( processTransactionWithEvents
  , processTransactionWithEvents'
  , postJournalEntry
  , revertJournalEntry
  , freezeAccount
  , unfreezeAccount
  , getAccountSnapshot
  , getFullState
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime, getCurrentTime)
import Data.Map.Strict (Map)
import Finance.Accounting
import qualified Infrastructure.EventStore.Accounting as IESA
import Surypus.CoreTypes (unDecimal)

-- | Process a transaction and emit events to the event store
processTransactionWithEvents :: IESA.AccountingEventStore -> Transaction -> IO (Either Text ())
processTransactionWithEvents store tx = do
  case validateTransaction tx of
    Left err -> pure $ Left err
    Right validTx -> do
      now <- getCurrentTime
      let txIdVal = maybe 0 id (txId validTx)
      res <- mapM (emitEntryEvent store now txIdVal) (txEntries validTx)
      case sequence res of
        Left err -> pure $ Left err
        Right _ -> pure $ Right ()

-- | Process transaction with events, returning the events emitted
processTransactionWithEvents' :: IESA.AccountingEventStore -> Transaction -> IO (Either Text [IESA.AccountingEvent])
processTransactionWithEvents' store tx = do
  case validateTransaction tx of
    Left err -> pure $ Left err
    Right validTx -> do
      now <- getCurrentTime
      let txIdVal = maybe 0 id (txId validTx)
      res <- mapM (emitEntryEvent' store now txIdVal) (txEntries validTx)
      case sequence res of
        Left err -> pure $ Left err
        Right events -> pure $ Right events

-- | Post a journal entry and emit event
postJournalEntry :: IESA.AccountingEventStore -> Int64 -> Int64 -> Int64 -> Double -> Text -> Day -> IO (Either Text ())
postJournalEntry store entryId debitAcc creditAcc amount currency date = do
  now <- getCurrentTime
  let event = IESA.JournalEntryPostedEvent IESA.JournalEntryPosted
        { IESA.jepEntryId = entryId
        , IESA.jepDebitAcc = debitAcc
        , IESA.jepCreditAcc = creditAcc
        , IESA.jepAmount = amount
        , IESA.jepCurrency = currency
        , IESA.jepDescription = "Journal entry #" <> T.pack (show entryId)
        , IESA.jepDate = date
        , IESA.jepTimestamp = now
        }
  IESA.appendAccountingEvent store event

-- | Revert a journal entry
revertJournalEntry :: IESA.AccountingEventStore -> Int64 -> Int64 -> Text -> IO (Either Text ())
revertJournalEntry store originalEntryId revertedById reason = do
  now <- getCurrentTime
  let event = IESA.EntryRevertedEvent IESA.EntryReverted
        { IESA.ervOriginalEntryId = originalEntryId
        , IESA.ervRevertedById = revertedById
        , IESA.ervReason = reason
        , IESA.ervTimestamp = now
        }
  IESA.appendAccountingEvent store event

-- | Freeze an account
freezeAccount :: IESA.AccountingEventStore -> Int64 -> Int64 -> Text -> IO (Either Text ())
freezeAccount store accountId frozenById reason = do
  now <- getCurrentTime
  let event = IESA.AccountFrozenEvent IESA.AccountFrozen
        { IESA.afAccountId = accountId
        , IESA.afFrozenById = frozenById
        , IESA.afReason = reason
        , IESA.afTimestamp = now
        }
  IESA.appendAccountingEvent store event

-- | Unfreeze an account
unfreezeAccount :: IESA.AccountingEventStore -> Int64 -> Int64 -> Text -> IO (Either Text ())
unfreezeAccount store accountId unfrozenById reason = do
  now <- getCurrentTime
  let event = IESA.AccountUnfrozenEvent IESA.AccountUnfrozen
        { IESA.ufAccountId = accountId
        , IESA.ufUnfrozenById = unfrozenById
        , IESA.ufReason = reason
        , IESA.ufTimestamp = now
        }
  IESA.appendAccountingEvent store event

-- | Get current snapshot for an account
getAccountSnapshot :: IESA.AccountingEventStore -> Int64 -> IO (Either Text (Maybe IESA.AccountSnapshot))
getAccountSnapshot = IESA.getAccountSnapshot

-- | Get full projected state for an account
getFullState :: IESA.AccountingEventStore -> Int64 -> IO (Either Text (Map Int64 IESA.AccountSnapshot))
getFullState = IESA.projectCurrentState

-- Internal helpers

emitEntryEvent :: IESA.AccountingEventStore -> UTCTime -> Int64 -> LedgerEntry -> IO (Either Text ())
emitEntryEvent store now newTxId entry =
   IESA.appendAccountingEvent store (mkEvent entry)
   where
     mkEvent e = IESA.JournalEntryPostedEvent IESA.JournalEntryPosted
       { IESA.jepEntryId = maybe newTxId id (leId e)
       , IESA.jepDebitAcc = fromIntegral (leAccount e)
       , IESA.jepCreditAcc = fromIntegral (leAccount e)
       , IESA.jepAmount = unDecimal (leDebit e)
       , IESA.jepCurrency = "RUB"
       , IESA.jepDescription = leDescription e
       , IESA.jepDate = leDate e
       , IESA.jepTimestamp = now
       }

emitEntryEvent' :: IESA.AccountingEventStore -> UTCTime -> Int64 -> LedgerEntry -> IO (Either Text IESA.AccountingEvent)
emitEntryEvent' store now newTxId' entry = do
   let event = mkEvent entry
   res <- IESA.appendAccountingEvent store event
   case res of
     Left err -> pure $ Left err
     Right () -> pure $ Right event
   where
     mkEvent e = IESA.JournalEntryPostedEvent IESA.JournalEntryPosted
       { IESA.jepEntryId = maybe newTxId' id (leId e)
       , IESA.jepDebitAcc = fromIntegral (leAccount e)
       , IESA.jepCreditAcc = fromIntegral (leAccount e)
       , IESA.jepAmount = unDecimal (leDebit e)
       , IESA.jepCurrency = "RUB"
       , IESA.jepDescription = leDescription e
       , IESA.jepDate = leDate e
       , IESA.jepTimestamp = now
       }
