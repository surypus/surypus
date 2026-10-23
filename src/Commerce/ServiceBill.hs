-- | ServiceBill module - Service bills
module Commerce.ServiceBill  where

import Data.Int (Int64)
import Data.Time (Day)

-- | ServiceBill - Service bill
data ServiceBill = ServiceBill
  { sbId :: Int64,
    sbCode :: String,
    sbDate :: Day,
    sbCustomerId :: Int64,
    sbTotal :: Double,
    sbPaid :: Double
  }
  deriving (Show, Eq)

-- | Get balance
-- | Clamped to 0: overpayment (sbPaid > sbTotal) must not produce a negative balance,
-- | mirroring the invariant enforced by Commerce.Invoice.calcInvoiceBalance.
getBalance :: ServiceBill -> Double
getBalance sb = max 0 (sbTotal sb - sbPaid sb)
