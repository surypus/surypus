-- | App.Tx — the single write path for ledger mutations.
--
-- Every accounting write must go through 'runWrite'. A repeated idempotency
-- key is a replay and returns the state unchanged; unbalanced entries are
-- rejected before they can reach storage.
module App.Tx
  ( IdempotencyKey (..)
  , TxError (..)
  , TxState (..)
  , emptyTxState
  , runWrite
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Set (Set)
import qualified Data.Set as S
import Data.Text (Text)
import Finance.Ledger
  ( AccTurn
  , Ledger (..)
  , TurnId
  , ledgerEntries
  , turnId
  , validateAccountingEquation
  )

newtype IdempotencyKey = IdempotencyKey { unIdempotencyKey :: Text }
  deriving (Show, Eq, Ord)

data TxError
  = UnbalancedEntry
  deriving (Show, Eq)

-- | Ledger plus the idempotency ledger. Kept separate from 'Ledger' so that
-- existing consumers of that record are not broken.
data TxState = TxState
  { txLedger :: Ledger
  , txKeys   :: Set IdempotencyKey
  } deriving (Show, Eq)

emptyTxState :: Ledger -> TxState
emptyTxState ledger = TxState ledger S.empty

-- | The only supported ledger write. Replays are no-ops; new entries are
-- accepted only when the accounting equation still balances afterwards.
runWrite :: IdempotencyKey -> TxState -> AccTurn -> Either TxError TxState
runWrite key st turn
  | key `S.member` txKeys st = Right st
  | otherwise =
      let ledger = txLedger st
          entries = M.insert (turnId turn) turn (ledgerEntries ledger)
          candidate = ledger { ledgerEntries = entries }
      in if validateAccountingEquation candidate
           then Right st { txLedger = candidate, txKeys = S.insert key (txKeys st) }
           else Left UnbalancedEntry
