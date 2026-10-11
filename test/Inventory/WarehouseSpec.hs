{-# LANGUAGE OverloadedStrings #-}

module Inventory.WarehouseSpec (spec) where

import Test.Hspec
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Maybe (isJust)

import Inventory.Warehouse

spec :: Spec
spec = do
  describe "Inventory.Warehouse - basic operations" $ do
    it "creates a warehouse and prevents duplicate codes" $ do
      let req = CreateWarehouseRequest "WH1" "Main Warehouse" MainWarehouse (Just "Address") (Just 1000)
      case createWarehouse [] req of
        WarehouseSuccess w -> do
          wCode w `shouldBe` "WH1"
          wName w `shouldBe` "Main Warehouse"
        _ -> fail "Expected success"

    it "rejects duplicate code" $ do
      let req = CreateWarehouseRequest "WH1" "Main Warehouse" MainWarehouse Nothing (Just 1000)
          existing = [case createWarehouse [] req of WarehouseSuccess w -> w; _ -> error "bad"]
      case createWarehouse existing req of
        WarehouseError _ -> (pure () :: IO ())
        _ -> fail "Expected duplicate code error"

    it "finds by code and reads/updates/deletes" $ do
      let req = CreateWarehouseRequest "WH2" "Branch" BranchWarehouse (Just "Addr") (Just 200)
      let WarehouseSuccess w = createWarehouse [] req
      findWarehouseByCode [w] "WH2" `shouldBe` Just w
      case updateWarehouse [w] (wId w) (UpdateWarehouseRequest (Just "Branch Updated") Nothing (Just 250)) of
        WarehouseSuccess u -> wName u `shouldBe` "Branch Updated"
        _ -> fail "Expected update"
      case deleteWarehouse [w] (wId w) of
        WarehouseSuccess d -> T.isInfixOf "archived" (wName d) `shouldBe` True
        _ -> fail "Expected delete"

    it "counts warehouses" $ do
      let w1 = Warehouse 1 "W1" "A" MainWarehouse Nothing (Just 100)
      let w2 = Warehouse 2 "W2" "B" BranchWarehouse Nothing (Just 200)
      countWarehouses [w1, w2] `shouldBe` 2
