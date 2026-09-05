-- | Terminal module - POS Terminals
module Retail.Terminal where

import Data.Int (Int64)
import Data.Text (Text)

-- | Terminal - POS Terminal
data Terminal = Terminal
  { trmId :: Int64,
    trmCode :: Text,
    trmLocationId :: Int64,
    trmStatus :: TerminalStatus
  }
  deriving (Show, Eq)

data TerminalStatus = TSOnline | TSOffline | TSError
  deriving (Show, Eq)

-- | Is terminal active
isTerminalActive :: Terminal -> Bool
isTerminalActive t = trmStatus t == TSOnline
