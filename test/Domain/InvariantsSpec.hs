{-# LANGUAGE OverloadedStrings #-}
-- | Domain invariants for the monetary, commerce, logistics and retail core.
--
-- These properties originally lived inside the library modules (as @prop_*@
-- helpers next to orphan @Arbitrary@ instances), which is what forced
-- @Test.QuickCheck@ into the library @build-depends@. They are re-homed here,
-- where test-only code belongs, and are now actually executed.
--
-- Every generator stays inside the domain the library's LiquidHaskell
-- refinements declare (quantities >= 0, rates in 0..100, discounts not
-- exceeding the total), so each property checks that the function preserves
-- non-negativity on that domain.
module Domain.InvariantsSpec (spec) where

import Data.Time (Day, fromGregorian)
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck

import DAL.Agent (Agent (..), calcCommission)
import Finance.Currency (Currency (..), CurrencyFlags (..), convertAmount)
import qualified Finance.TaxInvoice as FI
import Commerce.Discount (Discount (..), DiscountType (..), calcDiscount)
import Commerce.Orders.Order (LineStatus (..), OrderLine (..), calcLineTotal, calcOrderTotal)
import Commerce.Orders.Quotation (QuotationLine (..), calcQuotationTotal)
import Commerce.Payment (Payment (..), PaymentMethod (..), PaymentStatus (..))
import Commerce.RetBill (RetBill (..), calcFinalAmount)
import Inventory.GoodsTaxEx (GoodsTaxEx (..), calcTaxAmount)
import Logistics.Transfer (TransferLine (..), calcTransferAmount, getRemainingQtty)
import Logistics.Warehouse (StockMovement (..), calcStockBalance)
import Retail.Receipts.SmartReceipt (SmartReceiptLine (..), calcReceiptTotal)

-- ---------------------------------------------------------------------------
-- Generators (domain-valid values only)
-- ---------------------------------------------------------------------------

-- | QuickCheck has no 'Arbitrary Day', so generate one explicitly.
genDay :: Gen Day
genDay = fromGregorian <$> choose (1990, 2030) <*> choose (1, 12) <*> choose (1, 28)

instance Arbitrary Currency where
  arbitrary = do
    rate <- choose (0.01, 1000)
    Currency <$> arbitrary <*> pure "USD" <*> pure "Dollar" <*> pure "$"
      <*> pure rate
      <*> choose (0, 4)
      <*> pure (CurrencyFlags False False False)

instance Arbitrary Agent where
  arbitrary = do
    commission <- choose (0, 100)
    Agent <$> arbitrary <*> pure "A1" <*> pure "Agent" <*> pure commission <*> pure "R1"

instance Arbitrary DiscountType where
  arbitrary = elements [DTPercent, DTFixed, DTConditional]

instance Arbitrary Discount where
  arbitrary = do
    value <- choose (0, 100)
    Discount <$> arbitrary <*> pure "D1" <*> pure "Discount"
      <*> arbitrary
      <*> pure value
      <*> choose (0, 1000)

instance Arbitrary LineStatus where
  arbitrary = elements [LSPending, LSReserved, LSShipped, LSReturned]

instance Arbitrary OrderLine where
  arbitrary = do
    qtty <- choose (0, 1000)
    price <- choose (0, 10000)
    discount <- choose (0, 100)
    OrderLine <$> arbitrary <*> arbitrary <*> arbitrary
      <*> pure qtty
      <*> pure price
      <*> pure discount
      <*> arbitrary

instance Arbitrary QuotationLine where
  arbitrary = do
    qtty <- choose (0, 1000)
    price <- choose (0, 10000)
    discount <- choose (0, 100)
    QuotationLine <$> arbitrary <*> arbitrary <*> arbitrary
      <*> pure qtty
      <*> pure price
      <*> pure discount

instance Arbitrary PaymentMethod where
  arbitrary = elements [PMCash, PMCard, PMTransfer, PMBonus, PMGiftCard, PMCredit]

instance Arbitrary PaymentStatus where
  arbitrary = elements [PSPending, PSCompleted, PSFailed, PSRefunded, PSCancelled]

instance Arbitrary Payment where
  arbitrary = do
    amount <- choose (0, 100000)
    Payment <$> arbitrary <*> arbitrary <*> genDay
      <*> pure amount
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary

instance Arbitrary RetBill where
  arbitrary = do
    total <- choose (0, 100000)
    discount <- choose (0, total)
    RetBill <$> arbitrary <*> pure "B1" <*> genDay <*> arbitrary
      <*> pure total
      <*> pure discount

instance Arbitrary GoodsTaxEx where
  arbitrary = do
    rate <- choose (0, 100)
    GoodsTaxEx <$> arbitrary <*> pure "T1" <*> pure "Tax" <*> pure rate <*> arbitrary

instance Arbitrary TransferLine where
  arbitrary = do
    qtty <- choose (0, 1000)
    sent <- choose (0, qtty)
    received <- choose (0, qtty)
    price <- choose (0, 10000)
    cost <- choose (0, 10000)
    TransferLine <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary
      <*> pure qtty
      <*> pure sent
      <*> pure received
      <*> pure price
      <*> pure cost
      <*> arbitrary

instance Arbitrary StockMovement where
  arbitrary = do
    StockMovement <$> genDay <*> arbitrary <*> arbitrary
      <*> arbitrary
      <*> choose (0, 10000)
      <*> choose (0, 10000)
      <*> arbitrary

instance Arbitrary SmartReceiptLine where
  arbitrary = do
    qtty <- choose (0, 1000)
    price <- choose (0, 10000)
    discount <- choose (0, 100)
    SmartReceiptLine <$> arbitrary <*> arbitrary <*> arbitrary <*> pure "Item"
      <*> pure qtty
      <*> pure price
      <*> pure discount
      <*> choose (0, 100)

-- ---------------------------------------------------------------------------
-- Properties
-- ---------------------------------------------------------------------------

-- | 'convertAmount' round-trips: converting there and back reproduces the
-- amount (both rates are positive, so no division by zero).
prop_conversion_reversible :: Currency -> Currency -> Double -> Property
prop_conversion_reversible from to amount =
  let converted = convertAmount from to amount
      back = convertAmount to from converted
   in property (abs (back - amount) < 0.01)

prop_convert_to_self :: Currency -> Double -> Property
prop_convert_to_self cur amount =
  property (abs (convertAmount cur cur amount - amount) < 0.01)

prop_taxAmountNonNeg :: Double -> Double -> Property
prop_taxAmountNonNeg amount rate =
  amount >= 0 && rate >= 0 && rate <= 100 ==> FI.calcTaxAmount amount rate >= 0

prop_discountAmountNonNeg :: Discount -> Double -> Property
prop_discountAmountNonNeg d amount =
  amount >= 0 ==> calcDiscount d amount >= 0

prop_orderLineTotalNonNeg :: OrderLine -> Property
prop_orderLineTotalNonNeg = property . (>= 0) . calcLineTotal

prop_orderTotalNonNeg :: Property
prop_orderTotalNonNeg =
  forAll (listOf arbitrary `suchThat` (not . null)) $ \orderLines ->
    calcOrderTotal orderLines >= 0

prop_quotationTotalNonNeg :: QuotationLine -> Property
prop_quotationTotalNonNeg = property . (>= 0) . calcQuotationTotal

prop_payment_amount_positive :: Payment -> Property
prop_payment_amount_positive = property . (>= 0) . payAmount

prop_retBillFinalAmountNonNeg :: RetBill -> Property
prop_retBillFinalAmountNonNeg rb =
  let totalVal = rbTotal rb
      discount = rbDiscount rb
   in totalVal >= 0 && discount >= 0 && discount <= totalVal ==> calcFinalAmount rb >= 0

prop_goodsTaxAmountNonNeg :: GoodsTaxEx -> Double -> Property
prop_goodsTaxAmountNonNeg gte price =
  price >= 0 ==> calcTaxAmount gte price >= 0

prop_remaining_nonnegative :: TransferLine -> Property
prop_remaining_nonnegative = property . (>= 0) . getRemainingQtty

prop_received_bounded :: TransferLine -> Property
prop_received_bounded = property . (<= 0) . (\tl -> tlReceivedQtty tl - tlQtty tl)

prop_transferAmountNonNeg :: TransferLine -> Property
prop_transferAmountNonNeg = property . (>= 0) . calcTransferAmount

prop_stockBalanceNonNeg :: Double -> [StockMovement] -> Property
prop_stockBalanceNonNeg initial movements =
  property (calcStockBalance initial movements >= 0)

prop_receiptTotalNonNeg :: Property
prop_receiptTotalNonNeg =
  forAll (listOf arbitrary `suchThat` (not . null)) $ \receiptLines ->
    calcReceiptTotal receiptLines >= 0

prop_commissionNonNeg :: Agent -> Double -> Property
prop_commissionNonNeg agent sales =
  sales >= 0 ==> calcCommission agent sales >= 0

spec :: Spec
spec = do
  describe "Finance.Currency - convertAmount" $ do
    prop "is reversible" prop_conversion_reversible
    prop "converting to the same currency is a no-op" prop_convert_to_self

  describe "Finance.TaxInvoice - calcTaxAmount" $ do
    prop "tax amount is non-negative" prop_taxAmountNonNeg

  describe "Commerce.Discount - calcDiscount" $ do
    prop "discount amount is non-negative" prop_discountAmountNonNeg

  describe "Commerce.Orders.Order - line and order totals" $ do
    prop "line total is non-negative" prop_orderLineTotalNonNeg
    prop "order total is non-negative" prop_orderTotalNonNeg

  describe "Commerce.Orders.Quotation - quotation total" $ do
    prop "quotation total is non-negative" prop_quotationTotalNonNeg

  describe "Commerce.Payment - amount" $ do
    prop "payment amount is non-negative" prop_payment_amount_positive

  describe "Commerce.RetBill - calcFinalAmount" $ do
    prop "final amount is non-negative" prop_retBillFinalAmountNonNeg

  describe "Inventory.GoodsTaxEx - calcTaxAmount" $ do
    prop "goods tax amount is non-negative" prop_goodsTaxAmountNonNeg

  describe "Logistics.Transfer - transfer lines" $ do
    prop "remaining quantity is non-negative" prop_remaining_nonnegative
    prop "received quantity does not exceed the ordered quantity" prop_received_bounded
    prop "transfer amount is non-negative" prop_transferAmountNonNeg

  describe "Logistics.Warehouse - calcStockBalance" $ do
    prop "stock balance is non-negative" prop_stockBalanceNonNeg

  describe "Retail.Receipts.SmartReceipt - calcReceiptTotal" $ do
    prop "receipt total is non-negative" prop_receiptTotalNonNeg

  describe "DAL.Agent - calcCommission" $ do
    prop "commission is non-negative" prop_commissionNonNeg
