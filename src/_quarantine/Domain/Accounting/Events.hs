-- | Accounting Events - Core event types for accounting domain
module Domain.Accounting.Events
  ( AccountingEvent  (..)
  , rebuildBalance
  ) where

import Data.Text (Text)
import Data.Time (UTCTime)

-- | Accounting event for a single entry
data AccountingEvent
  = EntryCreated Int Int Text Double Double Text UTCTime
  deriving (Show, Eq)

-- | Rebuild account balance from a list of events
rebuildBalance :: Text -> [AccountingEvent] -> Double
rebuildBalance accCode events = accCode `seq` sum (map extractAmount events)

extractAmount :: AccountingEvent -> Double
extractAmount (EntryCreated _ _ _ d c _ _) = d - c