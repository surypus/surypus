-- | RetBill module - Retail bills
module Commerce.RetBill
  ( RetBill   (..),
    calcFinalAmount,
  ) where

import Data.Int (Int64)
import Data.Time (Day, fromGregorian)

{-@ type NonNeg = {v:Double | v >= 0} @-}

-- | RetBill - Retail bill (чек)
data RetBill = RetBill
  { rbId :: Int64,
    rbNumber :: String,
    rbDate :: Day,
    rbTerminalId :: Int64,
    rbTotal :: Double,
    rbDiscount :: Double
  }
  deriving (Show, Eq)

-- | Calculate final amount

{-@ calcFinalAmount :: RetBill -> NonNeg @-}
calcFinalAmount :: RetBill -> Double
calcFinalAmount rb = rbTotal rb - rbDiscount rb
