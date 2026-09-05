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
getBalance :: ServiceBill -> Double
getBalance sb = sbTotal sb - sbPaid sb
