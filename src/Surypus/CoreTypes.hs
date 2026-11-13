-- | Surypus core types
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Surypus.CoreTypes
  ( Decimal   (..),
    unDecimal,
    NonNeg (..),
    mkNonNeg,
    unNonNeg
  ) where

import Data.Aeson (ToJSON (..), FromJSON (..))
import Prelude hiding (div)

newtype Decimal = Decimal Double
  deriving (Show, Eq, Num, Ord, Fractional)

unDecimal :: Decimal -> Double
unDecimal (Decimal d) = d

div :: Double -> Double -> Double
div = (/)

instance ToJSON Decimal where
  toJSON (Decimal d) = toJSON d

instance FromJSON Decimal where
  parseJSON v = Decimal <$> parseJSON v

-- | Non-negative decimal wrapper for validation
newtype NonNeg = NonNeg Decimal
  deriving (Show, Eq, Ord)

-- | Smart constructor that ensures non-negative values
mkNonNeg :: Decimal -> Maybe NonNeg
mkNonNeg d
  | d >= 0 = Just (NonNeg d)
  | otherwise = Nothing

-- | Extract the underlying Decimal value
unNonNeg :: NonNeg -> Decimal
unNonNeg (NonNeg d) = d