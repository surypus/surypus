{-# LANGUAGE OverloadedStrings #-}

module Inventory.StockSpec (spec) where

import Test.Hspec
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T

import Inventory.StockOps
import Test.QuickCheck

instance Arbitrary InvStock where
  arbitrary =
    InvStock
      <$> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary

prop_totalQuantityForGood_equalsSum :: [InvStock] -> Int64 -> Bool
prop_totalQuantityForGood_equalsSum stocks gid =
  totalQuantityForGood stocks gid == sum [isQty s | s <- stocks, isGoodsId s == gid]

prop_transfer_preservesQuantity ::
     [InvStock] -> Double -> Int -> Int -> Property
prop_transfer_preservesQuantity stocks qty fromW toW =
  let before = totalQuantityForGood stocks 1
      mv = StockMovement Transfer 1 (Just (fromIntegral fromW)) (Just (fromIntegral toW)) qty Nothing
      after = case applyMovement stocks mv of
        Left _ -> totalQuantityForGood stocks 1
        Right ss -> totalQuantityForGood ss 1
  in before === after

spec :: Spec
spec = do
  describe "Inventory.StockOps - basic movements" $ do
    it "receives stock into empty warehouse" $ do
      let mv = StockMovement Receipt 1 Nothing (Just 10) 50 Nothing
      case applyMovement [] mv of
        Right stocks -> length stocks `shouldBe` 1
        Left err -> fail (T.unpack err)

    it "issues stock when available" $ do
      let s = InvStock 1 1 10 100 0
      let mv = StockMovement Issue 1 (Just 10) Nothing 30 Nothing
      case applyMovement [s] mv of
        Right stocks -> case findStock stocks 1 10 of
          Just r -> isQty r `shouldBe` 70
          Nothing -> fail "Stock missing"
        Left err -> fail (T.unpack err)

    it "rejects issue when insufficient" $ do
      let s = InvStock 1 1 10 20 0
      let mv = StockMovement Issue 1 (Just 10) Nothing 30 Nothing
      case applyMovement [s] mv of
        Left _ -> (pure () :: IO ())
        Right _ -> fail "Expected failure"

    it "transfers stock between warehouses" $ do
      let s1 = InvStock 1 1 10 100 0
      let s2 = InvStock 2 1 20 10 0
      let mv = StockMovement Transfer 1 (Just 10) (Just 20) 40 Nothing
      case applyMovement [s1, s2] mv of
        Right stocks -> do
          let Just from = findStock stocks 1 10
          let Just to = findStock stocks 1 20
          isQty from `shouldBe` 60
          isQty to `shouldBe` 50
        Left err -> fail (T.unpack err)

    it "adjusts stock absolute quantity" $ do
      let s1 = InvStock 1 1 10 100 0
      let mv = StockMovement Adjustment 1 (Just 10) Nothing 250 Nothing
      case applyMovement [s1] mv of
        Right stocks -> case findStock stocks 1 10 of
          Just r -> isQty r `shouldBe` 250
          Nothing -> fail "Stock missing"
        Left err -> fail (T.unpack err)

  describe "Inventory.StockOps - QuickCheck invariants" $ do
    it "totalQuantityForGood equals the sum of quantities for that good" $
      forAll arbitrary $ \stocks ->
        forAll (choose (0, 1000) :: Gen Int64) $ \gid ->
          property (prop_totalQuantityForGood_equalsSum stocks gid)

    it "a transfer preserves total quantity for the good" $
      forAll arbitrary $ \stocks ->
        forAll (choose (1, 200) :: Gen Double) $ \qty ->
          forAll (choose (1, 2) :: Gen Int) $ \fromW ->
          forAll (choose (1, 2) :: Gen Int) $ \toW ->
            property (prop_transfer_preservesQuantity stocks qty fromW toW)
