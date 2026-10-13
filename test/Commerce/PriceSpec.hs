-- | First coverage for 'Commerce.Price' — the pricing, discount, quotation and
-- validation layer (pure, exposed, zero importers in src/+test/ before this run).
--
-- Pins the documented semantics of every exported function:
--   * applyDiscount never pushes a price below zero in EITHER branch — the
--     percentage branch used to be unclamped, so a discount over 100%
--     produced a negative price (calcFinalPrice applies discounts without
--     validating them first, so the negative result reached a customer bill);
--   * convertCurrency / priceWithoutVAT never divide by zero — a missing
--     exchange rate (0) or a -100% VAT rate used to yield Infinity/NaN,
--     values that compare false against everything and so silently corrupt
--     any downstream total;
--   * findBestQuot filters on the validity window (from/to) AND the minimum
--     quantity before picking the cheapest surviving quotation;
--   * calcFinalPrice applies only discounts whose dMinSum is met;
-- The three validators agree with the functions they guard.
{-# LANGUAGE OverloadedStrings #-}
module Commerce.PriceSpec (spec) where

import Test.Hspec
import Test.QuickCheck

import Data.Int (Int64)
import Data.Time (Day, fromGregorian, toGregorian)
import Commerce.Price

spec :: Spec
spec = do
  describe "Commerce.Price.applyDiscount" $ do
    it "applies a percentage discount" $
      applyDiscount 1000 (mkDisc 10 True) `shouldBe` 900

    it "applies an absolute discount" $
      applyDiscount 1000 (mkDisc 250 False) `shouldBe` 750

    it "clamps an absolute discount larger than the price to zero" $
      applyDiscount 1000 (mkDisc 1500 False) `shouldBe` 0

    it "clamps a percentage discount over 100 to zero instead of going negative" $
      applyDiscount 1000 (mkDisc 150 True) `shouldBe` 0

    it "clamps a discount exactly equal to the price to zero" $
      applyDiscount 1000 (mkDisc 1000 False) `shouldBe` 0

    it "leaves the price untouched for a zero discount" $ do
      applyDiscount 1000 (mkDisc 0 True) `shouldBe` 1000
      applyDiscount 1000 (mkDisc 0 False) `shouldBe` 1000

    it "never yields a negative price, and never exceeds the original" $
      -- The generator is bounded deliberately: QuickCheck's default Double
      -- generator concentrates on small magnitudes, so a percentage discount
      -- over 100 (the case that used to go negative) would almost never be
      -- drawn and the property would pass vacuously against the bug.
      forAll (choose (0, 1e6)) $ \base ->
        forAll (choose (0, 500)) $ \v ->
          forAll (choose (0, 5000)) $ \vAbs ->
            property (\(pct :: Bool) ->
                        let r = applyDiscount base (mkDisc (if pct then v else vAbs) pct)
                         in r >= 0 && r <= base + 1e-9)

  describe "Commerce.Price.calcDiscountPercent" $ do
    it "computes the discount percentage" $
      calcDiscountPercent 1000 900 `shouldBe` 10

    it "returns zero for no discount" $
      calcDiscountPercent 1000 1000 `shouldBe` 0

    it "returns zero for a zero original price instead of dividing by zero" $
      calcDiscountPercent 0 500 `shouldBe` 0

    it "returns zero for a negative original price" $
      calcDiscountPercent (-100) 50 `shouldBe` 0

  describe "Commerce.Price.roundPrice" $ do
    it "rounds to the requested precision" $ do
      roundPrice 2 10.126 `shouldBe` 10.13
      roundPrice 0 10.6 `shouldBe` 11
      roundPrice 2 10.0 `shouldBe` 10.0

    it "rounds a negative amount" $
      roundPrice 2 (-10.126) `shouldBe` (-10.13)

  describe "Commerce.Price.convertCurrency" $ do
    it "converts at the given rates" $
      convertCurrency 100 2.0 1.0 `shouldBe` 200

    it "is an identity for equal rates" $
      convertCurrency 100 1.0 1.0 `shouldBe` 100

    it "returns the price unchanged for a zero target rate instead of Infinity" $
      convertCurrency 100 1.0 0 `shouldBe` 100

    it "returns the price unchanged for zero source and target rates instead of NaN" $
      convertCurrency 100 0 0 `shouldBe` 100

    it "never yields a non-finite result (property)" $
      forAll (choose (0, 1e6)) $ \p ->
        forAll (choose (0, 1e6)) $ \f ->
          forAll (choose (0, 1e6)) $ \t ->
            let r = convertCurrency p f t
             in not (isNaN r) && not (isInfinite r)

  describe "Commerce.Price.priceWithVAT" $ do
    it "adds the VAT rate" $ do
      priceWithVAT 1000 20 `shouldBe` 1200
      priceWithVAT 1000 0 `shouldBe` 1000

  describe "Commerce.Price.priceWithoutVAT" $ do
    it "strips the VAT rate" $
      abs (priceWithoutVAT 1200 20 - 1000) < 1e-9 `shouldBe` True

    it "is the inverse of priceWithVAT (property)" $
      forAll (choose (0, 1e6)) $ \p ->
        forAll (choose (0, 1e4)) $ \rate ->
          let gross = priceWithVAT p rate
           in abs (priceWithoutVAT gross rate - p) < 1e-6

    it "returns the price unchanged for a -100% rate instead of dividing by zero" $
      priceWithoutVAT 100 (-100) `shouldBe` 100

    it "never yields a non-finite result (property)" $
      forAll (choose (0, 1e6)) $ \p ->
        forAll (choose (-1e6, 1e6)) $ \rate ->
          let r = priceWithoutVAT p rate
           in not (isNaN r) && not (isInfinite r)

  describe "Commerce.Price.findBestQuot" $ do
    it "picks the cheapest valid quotation" $
      findBestQuot [q 1 100, q 2 80, q 3 120] 10 day `shouldBe` Just (q 2 80)

    it "returns Nothing when no quotation is valid" $
      findBestQuot [] 10 day `shouldBe` Nothing

    it "ignores quotations whose validity window has not started" $
      findBestQuot [qFrom 1 100 (addDays 1 day), q 2 80] 10 day
        `shouldBe` Just (q 2 80)

    it "ignores quotations whose validity window has expired" $
      findBestQuot [qTo 1 100 (addDays (-1) day), q 2 80] 10 day
        `shouldBe` Just (q 2 80)

    it "keeps a quotation whose end date is exactly today" $
      findBestQuot [qTo 1 80 day, q 2 120] 10 day `shouldBe` Just (qTo 1 80 day)

    it "keeps a quotation whose start date is exactly today" $
      findBestQuot [qFrom 1 80 day, q 2 120] 10 day `shouldBe` Just (qFrom 1 80 day)

    it "keeps an open-ended quotation (no end date)" $
      findBestQuot [qOpen 1 80, q 2 120] 10 day `shouldBe` Just (qOpen 1 80)

    it "ignores quotations below the requested minimum quantity" $
      findBestQuot [qMin 1 80 100, q 2 120] 10 day `shouldBe` Just (q 2 120)

    it "selects the cheapest among the quantity-eligible ones" $
      findBestQuot [qMin 1 80 100, qMin 2 90 5, qMin 3 70 200] 10 day
        `shouldBe` Just (qMin 2 90 5)

  describe "Commerce.Price.calcFinalPrice" $ do
    it "applies all applicable discounts and rounds to 2 decimals" $
      calcFinalPrice 1000 0 [mkDisc 10 True, mkDisc 50 False] `shouldBe` 855

    it "ignores discounts whose minimum sum is not met" $
      calcFinalPrice 1000 0 [mkDiscMin 10 True 5000, mkDiscMin 5 True 0] `shouldBe` 950

    it "returns the rounded price with no discounts" $
      calcFinalPrice 1000 0 [] `shouldBe` 1000

    it "never yields a negative price when a discount exceeds the total" $
      calcFinalPrice 1000 0 [mkDisc 10 True, mkDisc 100 True] `shouldBe` 0

  describe "Commerce.Price validators" $ do
    it "validatePrice accepts zero and positive prices and rejects negative" $ do
      validatePrice 0 `shouldBe` True
      validatePrice 100 `shouldBe` True
      validatePrice (-1) `shouldBe` False

    it "validateDiscount accepts a percentage within 0..100" $ do
      validateDiscount (mkDisc 0 True) `shouldBe` True
      validateDiscount (mkDisc 100 True) `shouldBe` True
      validateDiscount (mkDisc 101 True) `shouldBe` False
      validateDiscount (mkDisc (-1) True) `shouldBe` False

    it "validateDiscount accepts any non-negative absolute value" $ do
      validateDiscount (mkDisc 0 False) `shouldBe` True
      validateDiscount (mkDisc 100000 False) `shouldBe` True
      validateDiscount (mkDisc (-1) False) `shouldBe` False

    it "validateQuot accepts zero price and minimum, rejects negative" $ do
      validateQuot (q 1 0) `shouldBe` True
      validateQuot (q 1 100) `shouldBe` True
      validateQuot (q 1 (-100)) `shouldBe` False
      validateQuot (qMinNeg 1 100) `shouldBe` False

    it "class guard: every validator accepts a well-formed value" $
      property $ \(n :: Double) ->
        let pct = fromIntegral (floor (abs n) `mod` 100) :: Double
            v = abs n
         in validatePrice v
              && validateDiscount (mkDisc pct True)
              && validateQuot (q 1 v)

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

day :: Day
day = fromGregorian 2024 6 15

addDays :: Integer -> Day -> Day
addDays n d = fromGregorian y m (fromIntegral (toInteger dd + n))
  where (y, m, dd) = toGregorian d

mkDisc :: Double -> Bool -> Discount
mkDisc v pct = Discount 1 "D" "discount" v pct 0 0 day Nothing 0

mkDiscMin :: Double -> Bool -> Double -> Discount
mkDiscMin v pct minSum = Discount 2 "DM" "discount" v pct minSum 0 day Nothing 0

q :: Int64 -> Double -> Quot
q i price = Quot i 1 1 1 price 0 1 day Nothing QFManual

qMinNeg :: Int64 -> Double -> Quot
qMinNeg i price = Quot i 1 1 1 price (-1) 1 day Nothing QFManual

qMin :: Int64 -> Double -> Double -> Quot
qMin i price minQ = Quot i 1 1 1 price minQ 1 day Nothing QFManual

qOpen :: Int64 -> Double -> Quot
qOpen i price = Quot i 1 1 1 price 0 1 day Nothing QFManual

qFrom :: Int64 -> Double -> Day -> Quot
qFrom i price from = Quot i 1 1 1 price 0 1 from Nothing QFManual

qTo :: Int64 -> Double -> Day -> Quot
qTo i price to = Quot i 1 1 1 price 0 1 day (Just to) QFManual
