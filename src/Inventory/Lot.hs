-- | Lot types - Stock lots/batches
module Inventory.Lot
  ( Lot   (..),
    LotStatus   (..),
    LotFlags   (..)
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, fromGregorian)
import Test.QuickCheck

-- | Lot - Stock lot (партия товара)
data Lot = Lot
  { lotId :: Int64,
    lotGoodsId :: Int64,
    lotLocationId :: Int64,
    lotQtty :: Double,
    lotCost :: Double,
    lotPrice :: Double,
    lotDate :: Day,
    lotExpiry :: Maybe Day,
    lotFlags :: Int,
    lotSerialNumber :: Maybe Text,
    lotSupplierId :: Maybe Int64,
    lotBillId :: Maybe Int64
  }
  deriving (Show, Eq)

-- | Lot status
data LotStatus
  = LSActive
  | LSClosed
  | LSExpired
  | LSReserved
  deriving (Show, Eq)

-- | Lot flags
data LotFlags = LotFlags
  { lfStrictSerial :: Bool,
    lfNegativeOk :: Bool,
    lfFifo :: Bool
  }
  deriving (Show, Eq)

instance Arbitrary Lot where
  arbitrary = do
    qtty <- suchThat arbitrary (>= 0)
    cost <- suchThat arbitrary (>= 0)
    price <- suchThat arbitrary (>= 0)
    pure $ Lot 0 0 0 qtty cost price (fromGregorian 2024 1 1) Nothing 0 Nothing Nothing Nothing

instance Arbitrary LotStatus where
  arbitrary = elements [LSActive, LSClosed, LSExpired, LSReserved]

instance Arbitrary LotFlags where
  arbitrary = LotFlags <$> arbitrary <*> arbitrary <*> arbitrary
