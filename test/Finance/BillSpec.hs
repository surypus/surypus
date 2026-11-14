{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module Finance.BillSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (forAll, property, (.&&.), (===), Gen, Property, choose, listOf)
import Data.Time.Calendar (fromGregorian)
import Finance.Bill

spec :: Spec
spec = do
  describe "Finance.Bill" $ do
    let testDate = fromGregorian 2024 1 15
        line1 = BillLine "Widget A" 2 50 20
        line2 = BillLine "Widget B" 1 100 10
        testBill = createBill "BILL-001" testDate "Customer X" [line1, line2]

    it "creates a draft bill" $ do
      billStatus testBill `shouldBe` BillDraft
      billNumber testBill `shouldBe` "BILL-001"
      length (billLines testBill) `shouldBe` 2

    it "calculates total with tax" $ do
      let (total, tax) = calculateBillTotal [line1, line2]
      -- line1: 2*50 + 20% = 100 + 20 = 120
      -- line2: 1*100 + 10% = 100 + 10 = 110
      total `shouldBe` 230.0
      tax `shouldBe` 30.0

    it "validates bill with lines" $ do
      validateBill testBill `shouldBe` Right ()

    it "rejects empty bill" $ do
      let emptyBill = createBill "EMPTY" testDate "Nobody" []
      validateBill emptyBill `shouldSatisfy` \case
        Left _ -> True
        Right _ -> False

    it "posts a valid bill" $ do
      postBill testBill `shouldBe` BillPostedOk

    it "rejects posting already posted bill" $ do
      let postedBill = testBill { billStatus = BillPosted }
      postBill postedBill `shouldBe` BillAlreadyPosted

    describe "QuickCheck properties" $ do
      it "calculateBillTotal: total = subtotal + tax" $ property prop_calculateBillTotal
      it "validateBill: accepts exactly bills with >=1 line and non-negative total" $ property prop_validateBill

-- ============================================================================
-- QuickCheck properties (2026-11-13)
-- ============================================================================

-- | Bill line with non-negative amounts (domain-valid generator).
genBillLine :: Gen BillLine
genBillLine = do
  qty <- choose (0, 1000000)
  price <- choose (0, 1000000)
  rate <- choose (0, 100000)
  pure BillLine
    { billLineDescription = "item"
    , billLineQuantity = qty
    , billLineUnitPrice = price
    , billLineTaxRate = rate
    }

-- | Arbitrary list of bill lines.
genBillLineList :: Gen [BillLine]
genBillLineList = listOf genBillLine

-- | total = subtotal + tax, and tax = Σ qty·price·rate/100 — holds for any
-- combination of quantities, prices and tax rates.
prop_calculateBillTotal :: Property
prop_calculateBillTotal =
  forAll genBillLineList $ \lines ->
    let (total, tax) = calculateBillTotal lines
        subtotal = sum [billLineQuantity l * billLineUnitPrice l | l <- lines]
        expectedTax = sum [billLineQuantity l * billLineUnitPrice l * billLineTaxRate l / 100 | l <- lines]
    in (total === (subtotal + expectedTax)) .&&. (tax === expectedTax)

-- | validateBill accepts exactly the bills with at least one line and a
-- non-negative total.
prop_validateBill :: Property
prop_validateBill =
  forAll genBillLineList $ \lines ->
    let bill = createBill "BILL-001" (fromGregorian 2024 1 15) "Customer" lines
    in case validateBill bill of
         Left _ -> property (null lines || billTotal bill < 0)
         Right () -> property (not (null lines) && billTotal bill >= 0)
