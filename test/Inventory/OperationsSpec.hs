-- | Tests for Inventory.Operations - the pure stock-operation invariant layer
-- (module header: "Inventory Operations with Formal Verification").
--
-- Pins the documented semantics of every exported function:
--   * every quantity-taking validator fails closed on qty <= 0
--     (class guard below, same shape as the Surypus.Validation guard);
--   * processIssue/processTransfer enforce the "cannot move more than the
--     source holds" invariant, with the qty == source boundary included;
--   * processReceipt applies no capacity rule - the module defines no
--     capacity concept anywhere, so its extra parameters do not constrain
--     validity (pinned, not invented);
--   * processTransfer's destination quantity does not constrain validity;
--   * checkNegativeStock reports strictly negative positions only
--     (qty == 0 is not a violation);
--   * recalculateBalance sums lot quantities and stays non-negative when
--     every lot is non-negative (the module's documented theorem).
module Inventory.OperationsSpec (spec) where

import Test.Hspec
import Test.QuickCheck

import Data.Time (Day, fromGregorian)
import Inventory.Lot (Lot (..))
import Inventory.Operations

-- | Local generator: the library no longer ships test scaffolding (the
-- Arbitrary instance that used to live in Inventory.Lot was removed so
-- Test.QuickCheck is not a library dependency).
instance Arbitrary Lot where
  arbitrary = do
    q <- arbitrary `suchThat` (>= 0)
    c <- arbitrary `suchThat` (>= 0)
    p <- arbitrary `suchThat` (>= 0)
    d <- genDay
    exp <- Just <$> genDay
    serial <- pure Nothing
    supplier <- arbitrary
    bill <- arbitrary
    (Lot <$> arbitrary
         <*> arbitrary
         <*> arbitrary
         <*> pure q
         <*> pure c
         <*> pure p
         <*> pure d
         <*> pure exp
         <*> arbitrary
         <*> pure serial
         <*> pure supplier
         <*> pure bill)

-- | QuickCheck has no Arbitrary Day, so generate one explicitly.
genDay :: Gen Day
genDay = fromGregorian <$> choose (1900, 2100) <*> choose (1, 12) <*> choose (1, 28)

spec :: Spec
spec = do
  describe "Inventory.Operations.validateStockOperation" $ do
    it "accepts a positive quantity" $
      validateStockOperation 10 `shouldBe` StockOpSuccess

    it "rejects a zero quantity" $
      validateStockOperation 0 `shouldBe` StockOpInvalidQuantity

    it "rejects a negative quantity" $
      validateStockOperation (-5) `shouldBe` StockOpInvalidQuantity

  describe "Inventory.Operations.processReceipt" $ do
    it "accepts a positive quantity into an empty balance" $
      processReceipt 0 25 0 `shouldBe` StockOpSuccess

    it "accepts a positive quantity onto an existing balance" $
      processReceipt 100 25 1000 `shouldBe` StockOpSuccess

    it "rejects a zero quantity" $
      processReceipt 100 0 1000 `shouldBe` StockOpInvalidQuantity

    it "rejects a negative quantity" $
      processReceipt 100 (-25) 1000 `shouldBe` StockOpInvalidQuantity

  describe "Inventory.Operations.processIssue" $ do
    it "issues when the quantity is available" $
      processIssue 100 30 `shouldBe` StockOpSuccess

    it "issues exactly the available quantity" $
      processIssue 100 100 `shouldBe` StockOpSuccess

    it "rejects issuing more than the available quantity" $
      processIssue 100 101 `shouldBe` StockOpInsufficientStock

    it "rejects issuing from an empty balance" $
      processIssue 0 1 `shouldBe` StockOpInsufficientStock

    it "rejects a zero quantity" $
      processIssue 100 0 `shouldBe` StockOpInvalidQuantity

    it "rejects a negative quantity" $
      processIssue 100 (-30) `shouldBe` StockOpInvalidQuantity

  describe "Inventory.Operations.processTransfer" $ do
    it "transfers when the source holds the quantity" $
      processTransfer 100 30 50 `shouldBe` StockOpSuccess

    it "transfers exactly the source quantity" $
      processTransfer 100 100 0 `shouldBe` StockOpSuccess

    it "rejects transferring more than the source holds" $
      processTransfer 100 101 0 `shouldBe` StockOpInsufficientStock

    it "rejects a zero quantity" $
      processTransfer 100 0 50 `shouldBe` StockOpInvalidQuantity

    it "rejects a negative quantity" $
      processTransfer 100 (-30) 50 `shouldBe` StockOpInvalidQuantity

    it "does not let the destination quantity affect validity" $
      processTransfer 100 30 0 `shouldBe` processTransfer 100 30 1000000

  describe "Inventory.Operations.checkNegativeStock" $ do
    it "reports only strictly negative positions" $
      checkNegativeStock [(1, 10), (2, -3), (3, 0)] `shouldBe` [(2, -3)]

    it "returns nothing for a healthy balance list" $
      checkNegativeStock [(1, 0), (2, 10)] `shouldBe` []

    it "returns nothing for an empty list" $
      checkNegativeStock [] `shouldBe` []

  describe "Inventory.Operations.recalculateBalance" $ do
    it "returns zero for no lots" $
      recalculateBalance [] `shouldBe` (0 :: Double)

    it "sums the lot quantities" $ do
      let lot q = Lot 1 1 1 q 0 0 (fromGregorian 2024 1 1) Nothing 0 Nothing Nothing Nothing
      recalculateBalance [lot 10, lot 20, lot 5] `shouldBe` (35 :: Double)

    it "stays non-negative when every lot is non-negative" $
      property $ \lots -> recalculateBalance lots >= (0 :: Double)

  describe "Inventory.Operations.recalculateBalance - theorem" $ do
    it "recalculates as the sum of lot quantities for arbitrary non-negative quantities" $
      property prop_recalculateBalance_eq_sumOfLotQtty
    it "stays non-negative when every lot is non-negative (theorem)" $
      property prop_recalculateBalance_nonneg

  describe "Inventory.Operations - class guard" $ do
    it "every quantity-taking validator fails closed on non-positive quantity and accepts a valid one" $ do
      let validators =
            [ ("validateStockOperation", validateStockOperation)
            , ("processReceipt", \q -> processReceipt 100 q 1000)
            , ("processIssue", \q -> processIssue 100 q)
            , ("processTransfer", \q -> processTransfer 100 q 50)
            ]
      let expect name expected actual =
            if actual == expected
              then (pure () :: IO ())
              else expectationFailure (name ++ ": expected " ++ show expected ++ ", got " ++ show actual)
      mapM_
        ( \ (name, f) -> do
            expect (name ++ " qty 0") StockOpInvalidQuantity (f 0)
            expect (name ++ " qty -1") StockOpInvalidQuantity (f (-1))
            expect (name ++ " qty 5") StockOpSuccess (f 5)
        )
        validators

-- ---------------------------------------------------------------------------
-- Property-based tests for recalculateBalance theorem
-- ---------------------------------------------------------------------------

-- | Helper: build a Lot with the given quantity (all other fields zero).
mkLot :: Double -> Lot
mkLot q = Lot 1 1 1 q 0 0 (fromGregorian 2024 1 1) Nothing 0 Nothing Nothing Nothing

-- | 'recalculateBalance' is the sum of lot quantities (pinned theorem).
prop_recalculateBalance_eq_sumOfLotQtty :: [Double] -> Property
prop_recalculateBalance_eq_sumOfLotQtty qs =
  recalculateBalance (map mkLot qs) === sum qs

-- | Non-negative Double generator (no negatives, no discards).
genNonNegDouble :: Gen Double
genNonNegDouble = choose (0, 100000)

-- | 'recalculateBalance' stays non-negative when every lot quantity is
-- non-negative (the module's documented invariant).
prop_recalculateBalance_nonneg :: Property
prop_recalculateBalance_nonneg =
  forAll (listOf genNonNegDouble) $ \qs ->
    recalculateBalance (map mkLot qs) >= 0


