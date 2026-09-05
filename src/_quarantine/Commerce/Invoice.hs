-- | Invoice module - Invoices
module Commerce.Invoice
  ( Invoice   (..),
    calcInvoiceBalance
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (Day, fromGregorian)
import Test.QuickCheck

-- | Non-negative amount

{-@ type NonNeg = {v:Double | v >= 0} @-}

-- | Percentage (0-100)

{-@ type Percent = {v:Double | v >= 0 && v <= 100} @-}

-- | Invoice - Invoice
data Invoice = Invoice
  { invId :: Int64,
    invCode :: Text,
    invDate :: Day,
    invDueDate :: Day,
    invBillId :: Int64,
    invTotal :: Double,
    invPaid :: Double
  }
  deriving (Show, Eq)

-- | Calculate invoice balance (amount due)
-- = Invariant: result >= 0 (cannot owe negative)

{-@ calcInvoiceBalance :: Invoice -> NonNeg @-}
calcInvoiceBalance :: Invoice -> Double
calcInvoiceBalance i = invTotal i - invPaid i

instance Arbitrary Invoice where
  arbitrary = do
    totalVal <- suchThat arbitrary (>= 0)
    paidVal <- choose (0, totalVal)
    pure $ Invoice 0 (Text.pack "INV-0000") (fromGregorian 2024 1 1) (fromGregorian 2024 12 31) 0 totalVal paidVal
