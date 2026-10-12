{-# LANGUAGE OverloadedStrings #-}

module Inventory.GoodsSpec (spec) where

import Test.Hspec
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T

import Inventory.Goods

spec :: Spec
spec = do
  describe "Inventory.Goods - basic operations" $ do
    it "creates goods and avoids duplicates" $ do
      let req = CreateGoodsRequest "CODE1" "Product A" Nothing (Just "BAR01") Nothing Product 1 Nothing 10 100 Nothing Nothing 5.0
      case createGoods [] req of
        GoodsSuccess g -> do
          gCode g `shouldBe` "CODE1"
          gName g `shouldBe` "Product A"
        _ -> fail "Expected success"

    it "rejects duplicate code" $ do
      let req = CreateGoodsRequest "CODE1" "Product A" Nothing (Just "BAR01") Nothing Product 1 Nothing 10 100 Nothing Nothing 5.0
          existing = [case createGoods [] req of GoodsSuccess g -> g; _ -> error "bad"]
      case createGoods existing req of
        GoodsConflict _ -> (pure () :: IO ())
        _ -> fail "Expected conflict"

    it "finds by code and barcode" $ do
      let req = CreateGoodsRequest "C2" "Product B" Nothing (Just "BAR02") Nothing Product 1 Nothing 0 100 Nothing Nothing 1.0
      let GoodsSuccess g = createGoods [] req
      findGoodsByCode [g] "C2" `shouldBe` Just g
      findGoodsByBarcode [g] "BAR02" `shouldBe` Just g

    it "calculates total inventory value" $ do
      let g1 = Goods 1 "A" "A" Nothing (Just "b1") Nothing Product GoodsActive 1 Nothing 10 100 Nothing Nothing Nothing Nothing 5.0 1.5 True
      let g2 = Goods 2 "B" "B" Nothing Nothing Nothing Product GoodsActive 1 Nothing 0 100 Nothing Nothing Nothing Nothing 2.0 1.2 True
      totalInventoryValue [g1, g2] `shouldBe` (5.0 * 1.5 + 2.0 * 1.2)

    it "lists goods for restocking (active with minimum-stock policy)" $ do
      let g1 = Goods 1 "A" "A" Nothing Nothing Nothing Product GoodsActive 1 Nothing 5 100 Nothing Nothing Nothing Nothing 1.0 1.0 True
      let g2 = Goods 2 "B" "B" Nothing Nothing Nothing Product GoodsActive 1 Nothing 50 100 Nothing Nothing Nothing Nothing 1.0 1.0 True
      let g3 = Goods 3 "C" "C" Nothing Nothing Nothing Product GoodsActive 1 Nothing 0 100 Nothing Nothing Nothing Nothing 1.0 1.0 True
      let g4 = Goods 4 "D" "D" Nothing Nothing Nothing Product GoodsInactive 1 Nothing 5 100 Nothing Nothing Nothing Nothing 1.0 1.0 False
      goodsForRestocking [g1, g2, g3, g4] `shouldBe` [g1, g2]
