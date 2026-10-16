{-# LANGUAGE OverloadedStrings #-}

module Inventory.GoodsSpec (spec) where

import Test.Hspec
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T

import Inventory.Goods
import Inventory.Stock (Stock (..))

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

    it "lists goods for restocking (below minimum, joined with stock)" $ do
      -- g1: minimum 5, on hand 2 reserved 0  -> available 2  -> restock
      -- g2: minimum 50, on hand 40 reserved 10 -> available 30 -> restock
      -- g3: no minimum policy (0)            -> never restock
      -- g4: inactive                         -> never restock
      -- g5: minimum 5, on hand 5             -> available 5  -> not below
      let g1 = Goods 1 "A" "A" Nothing Nothing Nothing Product GoodsActive 1 Nothing 5 100 Nothing Nothing Nothing Nothing 1.0 1.0 True
      let g2 = Goods 2 "B" "B" Nothing Nothing Nothing Product GoodsActive 1 Nothing 50 100 Nothing Nothing Nothing Nothing 1.0 1.0 True
      let g3 = Goods 3 "C" "C" Nothing Nothing Nothing Product GoodsActive 1 Nothing 0 100 Nothing Nothing Nothing Nothing 1.0 1.0 True
      let g4 = Goods 4 "D" "D" Nothing Nothing Nothing Product GoodsInactive 1 Nothing 5 100 Nothing Nothing Nothing Nothing 1.0 1.0 False
      let g5 = Goods 5 "E" "E" Nothing Nothing Nothing Product GoodsActive 1 Nothing 5 100 Nothing Nothing Nothing Nothing 1.0 1.0 True
          stocks =
            [ Stock 1 10 2 0 0 1.0 1.0
            , Stock 2 10 40 10 0 1.0 1.0
            , Stock 3 10 0 0 0 1.0 1.0
            , Stock 4 10 2 0 0 1.0 1.0
            , Stock 5 10 5 0 0 1.0 1.0
            ]
      goodsForRestocking [g1, g2, g3, g4, g5] stocks `shouldBe` [g1, g2]

    it "sums available quantity across locations" $ do
      -- 3 on hand at location 10, 4 on hand at location 11, 2 reserved at 11
      -- -> available 5, minimum 6 -> restock
      let g = Goods 1 "A" "A" Nothing Nothing Nothing Product GoodsActive 1 Nothing 6 100 Nothing Nothing Nothing Nothing 1.0 1.0 True
          stocks =
            [ Stock 1 10 3 0 0 1.0 1.0
            , Stock 1 11 4 2 0 1.0 1.0
            ]
      goodsForRestocking [g] stocks `shouldBe` [g]

    it "reports nothing when stock is not below the minimum" $ do
      let g = Goods 1 "A" "A" Nothing Nothing Nothing Product GoodsActive 1 Nothing 5 100 Nothing Nothing Nothing Nothing 1.0 1.0 True
      goodsForRestocking [g] [Stock 1 10 5 0 0 1.0 1.0] `shouldBe` []

    it "treats an empty stock list as zero on hand" $ do
      let g = Goods 1 "A" "A" Nothing Nothing Nothing Product GoodsActive 1 Nothing 5 100 Nothing Nothing Nothing Nothing 1.0 1.0 True
      goodsForRestocking [g] [] `shouldBe` [g]
