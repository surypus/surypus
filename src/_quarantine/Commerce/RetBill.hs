-- | RetBill module - Retail bills
module Commerce.RetBill
  ( RetBill   (..),
    calcFinalAmount,
    prop_retBillFinalAmountNonNeg
  ) where

import Data.Int (Int64)
import Data.Time (Day, fromGregorian)
import Test.QuickCheck

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

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary RetBill where
  arbitrary = do
    totalVal <- suchThat arbitrary (>= 0)
    discount <- choose (0, totalVal)
    pure $ RetBill 0 "" (fromGregorian 2024 1 1) 0 totalVal discount

prop_retBillFinalAmountNonNeg :: RetBill -> Property
prop_retBillFinalAmountNonNeg rb =
  let totalVal = rbTotal rb
      discount = rbDiscount rb
   in totalVal >= 0 && discount >= 0 && discount <= totalVal ==> calcFinalAmount rb >= 0
