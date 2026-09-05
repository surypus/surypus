{-# LANGUAGE OverloadedStrings #-}

-- | Discount module - Discounts
module Commerce.Discount
  ( Discount   (..),
    DiscountType   (..),
    calcDiscount,
    prop_discountAmountNonNeg
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ type Percent = {v:Double | v >= 0 && v <= 100} @-}

-- | Discount - Discount rule
data Discount = Discount
  { dscId :: Int64,
    dscCode :: Text,
    dscName :: Text,
    dscType :: DiscountType,
    dscValue :: Double,
    dscMinAmount :: Double
  }
  deriving (Show, Eq)

data DiscountType = DTPercent | DTFixed | DTConditional
  deriving (Show, Eq)

-- | Calculate discount amount

{-@ calcDiscount :: Discount -> amount:NonNeg -> NonNeg @-}
calcDiscount :: Discount -> Double -> Double
calcDiscount d amount
  | amount >= dscMinAmount d = case dscType d of
      DTPercent -> amount * dscValue d / 100
      DTFixed -> dscValue d
      DTConditional -> amount * dscValue d / 100
  | otherwise = 0

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary Discount where
  arbitrary = do
    dtype <- elements [DTPercent, DTFixed, DTConditional]
    value <- suchThat arbitrary (>= 0)
    minAmt <- suchThat arbitrary (>= 0)
    pure $ Discount 0 "" "" dtype value minAmt

prop_discountAmountNonNeg :: Discount -> Double -> Property
prop_discountAmountNonNeg d amount =
  amount >= 0 ==> calcDiscount d amount >= 0
