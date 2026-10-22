-- | First coverage for `Commerce.Payment` — the payments layer (pure, exposed,
-- zero importers in src/+test/ before this run).
--
-- Pins the documented invariants of every exported predicate:
--   * `isCompleted` — true only for completed payments;
--   * `canRefund`   — true only for completed payments with a strictly
--     positive amount (a zero-amount payment can never be refunded);
--   * `calcPaymentAmount` — never returns a negative amount;
--   * `validatePayment`   — true only for payments with a positive amount;
-- The invariants hold for COMPLETELY arbitrary records (any status,
-- any amount, any date, any method), so these properties guard the
-- module's contract against future refactors.
{-# LANGUAGE OverloadedStrings #-}
module Commerce.PaymentSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Arbitrary, Gen, Property, forAll, elements, oneof, suchThat, arbitrary, choose, (===), property)
import Data.Int (Int64)
import Data.Time (Day, fromGregorian)

import Commerce.Payment

-- ============================================================================
-- Generators
-- ============================================================================

genPaymentMethod :: Gen PaymentMethod
genPaymentMethod = elements [PMCash, PMCard, PMTransfer, PMBonus, PMGiftCard, PMCredit]

genPaymentStatus :: Gen PaymentStatus
genPaymentStatus =
  elements [PSPending, PSCompleted, PSFailed, PSRefunded, PSCancelled]

genPaymentFlags :: Gen PaymentFlags
genPaymentFlags =
  PaymentFlags <$> arbitrary <*> arbitrary <*> arbitrary

genPayment :: Gen Payment
genPayment =
  Payment
    <$> arbitrary
    <*> arbitrary
    <*> (fromGregorian <$> choose (2020, 2030) <*> choose (1, 12) <*> choose (1, 28))
    <*> arbitrary
    <*> genPaymentMethod
    <*> genPaymentStatus
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary

-- ============================================================================
-- Properties
-- ============================================================================

-- | `isCompleted` is true exactly for PSCompleted payments.
prop_isCompleted :: Property
prop_isCompleted =
  forAll genPayment $ \p ->
    isCompleted p === (payStatus p == PSCompleted)

-- | `canRefund` is true exactly for completed payments with a strictly
-- positive amount.
prop_canRefund :: Property
prop_canRefund =
  forAll genPayment $ \p ->
    canRefund p === (payStatus p == PSCompleted && payAmount p > 0)

-- | `calcPaymentAmount` is never negative, regardless of input.
prop_calcPaymentAmount_nonNeg :: Double -> Property
prop_calcPaymentAmount_nonNeg x =
  property (calcPaymentAmount x >= 0)

-- | `validatePayment` is true exactly for payments with a positive amount.
prop_validatePayment :: Property
prop_validatePayment =
  forAll genPayment $ \p ->
    validatePayment p === (payAmount p > 0)

-- ============================================================================
-- Spec
-- ============================================================================

spec :: Spec
spec = do
  describe "Commerce.Payment.isCompleted" $ do
    prop "is true only for PSCompleted" prop_isCompleted

  describe "Commerce.Payment.canRefund" $ do
    prop "is true only for completed positive payments" prop_canRefund

  describe "Commerce.Payment.calcPaymentAmount" $ do
    prop "is never negative" prop_calcPaymentAmount_nonNeg

  describe "Commerce.Payment.validatePayment" $ do
    prop "is true only for positive amounts" prop_validatePayment

-- ============================================================================
-- Arbitrary instances (required for the properties above)
-- ============================================================================

instance Arbitrary PaymentMethod where
  arbitrary = genPaymentMethod

instance Arbitrary PaymentStatus where
  arbitrary = genPaymentStatus

instance Arbitrary PaymentFlags where
  arbitrary = genPaymentFlags

instance Arbitrary Payment where
  arbitrary = genPayment
