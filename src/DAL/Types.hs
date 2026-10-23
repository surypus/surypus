-- Ledger entry: single canonical type for double-entry bookkeeping (Phase 3).
module DAL.Types (LedgerEntry, EntryId, leDebit, leCredit, leAmount) where

data LedgerEntry = LedgerEntry
  { leId     :: EntryId
  , leDebit  :: Text
  , leCredit :: Text
  , leAmount :: Decimal
  } deriving (Eq, Show)

type EntryId = Int
