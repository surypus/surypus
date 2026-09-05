-- | BillTaxDiffs module - Bill tax differences
module Commerce.BillTaxDiffs  where

import Data.Int (Int64)

-- | BillTaxDiffs - Bill tax differences
data BillTaxDiffs = BillTaxDiffs
  { btdId :: Int64,
    btdBillId :: Int64,
    btdTaxId :: Int64,
    btdTaxable :: Double,
    btdTaxAmount :: Double
  }
  deriving (Show, Eq)

-- | Get total tax
getTotalTax :: BillTaxDiffs -> Double
getTotalTax = btdTaxAmount
