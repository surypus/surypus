-- | TaxInvoice module - Tax invoices
module Finance.TaxInvoice
  ( TaxInvoice   (..),
    calcTaxAmount,
  ) where

import Data.Int (Int64)
import Data.Time (Day)

{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ type TaxRate = {v:Double | v >= 0 && v <= 100} @-}

-- | TaxInvoice - Tax invoice
data TaxInvoice = TaxInvoice
  { tiId :: Int64,
    tiNumber :: String,
    tiDate :: Day,
    tiBillId :: Int64,
    tiTotal :: Double,
    tiTaxAmount :: Double
  }
  deriving (Show, Eq)

-- | Calculate tax amount

{-@ calcTaxAmount :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}
calcTaxAmount :: Double -> Double -> Double
calcTaxAmount amount rate = amount * rate / 100
