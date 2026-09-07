-- | Core Services Accounting (Phase 1: stub)
module Core.Services.Accounting
  ( processTransactionWithEvents
  , processTransactionWithEvents'
  , validateTransaction
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime, getCurrentTime)
import Data.Map.Strict (Map)
import qualified Finance.Accounting as FA

-- | Accounting event store (stub)
data AccountingEventStore = AccountingEventStore

-- | Accounting event (stub)
data AccountingEvent = AccountingEvent
  { accountingEventId :: !Int64
  , accountingEventType :: !Text
  } deriving (Show, Eq)

-- | Validate transaction (stub)
validateTransaction :: FA.Transaction -> Either Text FA.Transaction
validateTransaction tx = Right tx

-- | Emit entry event (stub)
emitEntryEvent :: AccountingEventStore -> UTCTime -> Int64 -> FA.LedgerEntry -> IO (Either Text ())
emitEntryEvent _ _ _ _ = return $ Right ()

-- | Process transaction with events (stub)
processTransactionWithEvents :: AccountingEventStore -> FA.Transaction -> IO (Either Text ())
processTransactionWithEvents _ _ = return $ Right ()

-- | Process transaction with events returning events (stub)
processTransactionWithEvents' :: AccountingEventStore -> FA.Transaction -> IO (Either Text [AccountingEvent])
processTransactionWithEvents' _ _ = return $ Right []
