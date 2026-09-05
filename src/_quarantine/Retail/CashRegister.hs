-- | CashRegister module - Cash registers
module Retail.CashRegister where

import Data.Int (Int64)
import Data.Text (Text)

-- | CashRegister - Cash register
data CashRegister = CashRegister
  { crId :: Int64,
    crCode :: Text,
    crTerminalId :: Int64,
    crBalance :: Double,
    crCurrencyId :: Int64
  }
  deriving (Show, Eq)

-- | Update balance
updateBalance :: CashRegister -> Double -> CashRegister
updateBalance cr amount = cr {crBalance = crBalance cr + amount}
