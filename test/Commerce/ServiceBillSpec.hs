{-# LANGUAGE OverloadedStrings #-}
module Commerce.ServiceBillSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import Data.Int (Int64)
import Data.Time (Day, fromGregorian)
import qualified Commerce.ServiceBill

spec :: Spec
spec = do
  describe "getBalance" $ do
    it "returns the remainder for a partial payment" $ do
      let sb = mkSB 1 "SB-001" (fromGregorian 2026 1 1) 10 1000.0 400.0
      Commerce.ServiceBill.getBalance sb `shouldBe` 600.0

    it "returns 0 for a fully paid bill" $ do
      let sb = mkSB 2 "SB-002" (fromGregorian 2026 1 1) 10 500.0 500.0
      Commerce.ServiceBill.getBalance sb `shouldBe` 0.0

    it "clamps overpayment to 0" $ do
      let sb = mkSB 3 "SB-003" (fromGregorian 2026 1 1) 11 250.0 500.0
      Commerce.ServiceBill.getBalance sb `shouldBe` 0.0

    it "returns 0 for a zero-total bill" $ do
      let sb = mkSB 4 "SB-004" (fromGregorian 2026 1 1) 12 0.0 0.0
      Commerce.ServiceBill.getBalance sb `shouldBe` 0.0

    it "is always non-negative (QuickCheck)" $ do
      property $ \total paid ->
        let sb = mkSB 1 "QC" (fromGregorian 2026 1 1) 1 (max 0 total) (max 0 paid)
        in Commerce.ServiceBill.getBalance sb >= (0.0 :: Double)

mkSB :: Int64 -> String -> Day -> Int64 -> Double -> Double -> Commerce.ServiceBill.ServiceBill
mkSB i code date custId total paid =
  Commerce.ServiceBill.ServiceBill
    { Commerce.ServiceBill.sbId = i
    , Commerce.ServiceBill.sbCode = code
    , Commerce.ServiceBill.sbDate = date
    , Commerce.ServiceBill.sbCustomerId = custId
    , Commerce.ServiceBill.sbTotal = total
    , Commerce.ServiceBill.sbPaid = paid
    }
