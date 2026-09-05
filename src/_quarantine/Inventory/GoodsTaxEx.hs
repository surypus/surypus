{-# LANGUAGE OverloadedStrings #-}

-- | GoodsTaxEx module - Extended goods tax
module Inventory.GoodsTaxEx
  ( GoodsTaxEx   (..),
    calcTaxAmount,
    prop_goodsTaxAmountNonNeg
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ type TaxRate = {v:Double | v >= 0 && v <= 100} @-}

-- | GoodsTaxEx - Extended goods tax
data GoodsTaxEx = GoodsTaxEx
  { gteId :: Int64,
    gteCode :: Text,
    gteName :: Text,
    gteTaxRate :: Double,
    gteFlags :: Int
  }
  deriving (Show, Eq)

-- | Calculate tax amount

{-@ calcTaxAmount :: GoodsTaxEx -> price:NonNeg -> NonNeg @-}
calcTaxAmount :: GoodsTaxEx -> Double -> Double
calcTaxAmount gte price = price * gteTaxRate gte / 100

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary GoodsTaxEx where
  arbitrary = do
    rate <- choose (0, 100 :: Double)
    pure $ GoodsTaxEx 0 "" "" rate 0

prop_goodsTaxAmountNonNeg :: GoodsTaxEx -> Double -> Property
prop_goodsTaxAmountNonNeg gte price =
  price >= 0 ==> calcTaxAmount gte price >= 0
