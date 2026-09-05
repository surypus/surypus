-- | Blockchain module - Blockchain integration
module DAL.Blockchain  where

import Data.Int (Int64)
import Data.Text (Text)

-- | SmartContract - Smart contract
data SmartContract = SmartContract
  { scId :: Int64,
    scAddress :: Text, -- Contract address
    scABI :: Text, -- JSON ABI
    scSource :: Text, -- Solidity source
    scCompiledAt :: Int64
  }
  deriving (Show, Eq)

-- | BlockchainTransaction - Transaction record
data BlockchainTransaction = BlockchainTransaction
  { btId :: Int64,
    btHash :: Text, -- TX hash
    btContractId :: Int64,
    btFrom :: Text,
    btTo :: Text,
    btValue :: Text, -- Wei
    btBlockNumber :: Int64,
    btStatus :: BlockchainStatus
  }
  deriving (Show, Eq)

data BlockchainStatus = BSPending | BSConfirmed | BSFailed
  deriving (Show, Eq)
