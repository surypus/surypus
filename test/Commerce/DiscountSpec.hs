{-# LANGUAGE OverloadedStrings #-}

module Commerce.DiscountSpec (spec) where

import Commerce.Discount
import Test.Hspec
import Test.QuickCheck

instance Arbitrary DiscountType where
  arbitrary = elements [DTPercent, DTFixed, DTConditional]

spec :: Spec
spec = describe "Commerce.Discount" $ do
  describe "calcDiscount" $ do
    it "DTPercent: amount >= minAmount → amount * value / 100" $
      let d = Discount 1 "D1" "Test" DTPercent 20 100
          result = calcDiscount d 200
      in result `shouldBe` 40.0  -- 200 * 20 / 100

    it "DTPercent: amount < minAmount → 0" $
      let d = Discount 1 "D1" "Test" DTPercent 20 100
          result = calcDiscount d 50
      in result `shouldBe` 0.0

    it "DTFixed: amount >= minAmount → value (independent of amount)" $
      let d = Discount 1 "D1" "Test" DTFixed 50 100
          result = calcDiscount d 1000
      in result `shouldBe` 50.0  -- always 50, not percentage

    it "DTFixed: amount < minAmount → 0" $
      let d = Discount 1 "D1" "Test" DTFixed 50 100
          result = calcDiscount d 99
      in result `shouldBe` 0.0

    it "DTConditional: amount >= minAmount → amount * value / 100" $
      let d = Discount 1 "D1" "Test" DTConditional 15 200
          result = calcDiscount d 500
      in result `shouldBe` 75.0  -- 500 * 15 / 100

    it "DTConditional: amount < minAmount → 0" $
      let d = Discount 1 "D1" "Test" DTConditional 15 200
          result = calcDiscount d 150
      in result `shouldBe` 0.0

    it "boundary: amount == minAmount → discount applied (>=)" $
      let d = Discount 1 "D1" "Test" DTPercent 25 100
          result = calcDiscount d 100
      in result `shouldBe` 25.0  -- 100 * 25 / 100

    it "boundary: amount == minAmount for DTFixed → value applied" $
      let d = Discount 1 "D1" "Test" DTFixed 30 100
          result = calcDiscount d 100
      in result `shouldBe` 30.0

    it "zero value → zero discount for all types" $ do
      let dp = Discount 1 "D1" "Test" DTPercent 0 0
          df = Discount 1 "D1" "Test" DTFixed 0 0
          dc = Discount 1 "D1" "Test" DTConditional 0 0
      calcDiscount dp 100 `shouldBe` 0.0
      calcDiscount df 100 `shouldBe` 0.0
      calcDiscount dc 100 `shouldBe` 0.0

  describe "properties" $ do
    it "prop_discountAmountNonNeg: discount is never negative" $
      property prop_discountAmountNonNeg

    it "DTFixed: result equals dscValue when amount >= minAmount" $
      property $ \(NonNegative value) (NonNegative minAmt) (NonNegative amount) ->
        let d = Discount 0 "" "" DTFixed value minAmt
            result = calcDiscount d amount
        in amount >= minAmt ==> result == value

    it "DTPercent: result is amount * value / 100 when amount >= minAmount" $
      property $ \(NonNegative value) (NonNegative minAmt) (NonNegative amount) ->
        let d = Discount 0 "" "" DTPercent value minAmt
            expected = amount * value / 100
        in amount >= minAmt ==> calcDiscount d amount == expected

    it "all types: amount < minAmount → 0" $
      property $ \dtype value (NonNegative amount) ->
        let d = Discount 0 "" "" dtype value (amount + 1)
        in calcDiscount d amount == 0.0
