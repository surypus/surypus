{-# LANGUAGE OverloadedStrings #-}

module DAL.IntegrationSpec where

import Test.Hspec
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import DAL.DB
import Test.DAL.Fixtures

spec :: Spec
spec = do
  describe "DAL.DB Integration Tests" $ do

    -- Database creation and initialization
    describe "Database initialization" $ do
      it "should create a new database with test data" $ do
        db <- newDatabase
        personsCount <- countPersons db
        goodsCount <- countGoods db
        personsCount `shouldBe` 3
        goodsCount `shouldBe` 3

      it "should have initial test locations" $ do
        db <- newDatabase
        locsCount <- countLocations db
        locsCount `shouldBe` 3

      it "should have initial stock records" $ do
        db <- newDatabase
        stockCount <- countStock db
        stockCount `shouldBe` 3

    -- Person CRUD operations
    describe "Person CRUD operations" $ do
      it "should insert a new person" $ do
        db <- newDatabase
        clearDatabase db
        let person = personFactory 1 "New Company"
        insertPerson db person
        count <- countPersons db
        count `shouldBe` 1

      it "should find a person by ID" $ do
        db <- newDatabase
        person <- findPersonById db 1
        case person of
          Just p -> pId p `shouldBe` 1
          Nothing -> fail "Person not found"

      it "should update a person" $ do
        db <- newDatabase
        let oldPerson = personFactory 1 "Old Name"
        insertPerson db oldPerson
        let newPerson = personFactory 1 "New Name"
        result <- updatePerson db 1 newPerson
        result `shouldBe` True
        updatedPerson <- findPersonById db 1
        case updatedPerson of
          Just p -> pName p `shouldBe` T.pack "New Name"
          Nothing -> fail "Person not found"

      it "should delete a person" $ do
        db <- newDatabase
        let person = personFactory 10 "To Delete"
        insertPerson db person
        countBefore <- countPersons db
        result <- deletePerson db 10
        result `shouldBe` True
        countAfter <- countPersons db
        countAfter `shouldBe` (countBefore - 1)

      it "should not find deleted person" $ do
        db <- newDatabase
        let person = personFactory 20 "To Delete"
        insertPerson db person
        _ <- deletePerson db 20
        found <- findPersonById db 20
        found `shouldBe` Nothing

      it "should query persons by type" $ do
        db <- newDatabase
        clearDatabase db
        mapM_ (insertPerson db) [
          personFactory 1 "Type 1" {pPersonType = 1},
          personFactory 2 "Type 2" {pPersonType = 2},
          personFactory 3 "Type 1 Again" {pPersonType = 1}
          ]
        type1Persons <- queryPersonsByType db 1
        length type1Persons `shouldBe` 2

    -- Goods CRUD operations
    describe "Goods CRUD operations" $ do
      it "should insert a new goods" $ do
        db <- newDatabase
        clearDatabase db
        let goods = goodsFactory 100 "New Product"
        insertGoods db goods
        count <- countGoods db
        count `shouldBe` 1

      it "should find goods by ID" $ do
        db <- newDatabase
        goods <- findGoodsById db 1
        case goods of
          Just g -> gId g `shouldBe` 1
          Nothing -> fail "Goods not found"

      it "should update goods" $ do
        db <- newDatabase
        let oldGoods = goodsFactory 100 "Old Product"
        insertGoods db oldGoods
        let newGoods = goodsFactory 100 "New Product"
        result <- updateGoods db 100 newGoods
        result `shouldBe` True

      it "should delete goods" $ do
        db <- newDatabase
        let goods = goodsFactory 200 "To Delete"
        insertGoods db goods
        countBefore <- countGoods db
        result <- deleteGoods db 200
        result `shouldBe` True
        countAfter <- countGoods db
        countAfter `shouldBe` (countBefore - 1)

    -- Location CRUD operations
    describe "Location CRUD operations" $ do
      it "should insert a new location" $ do
        db <- newDatabase
        clearDatabase db
        let location = locationFactory 100 "New Warehouse"
        insertLocation db location
        count <- countLocations db
        count `shouldBe` 1

      it "should find location by ID" $ do
        db <- newDatabase
        location <- findLocationById db 1
        case location of
          Just l -> lId l `shouldBe` 1
          Nothing -> fail "Location not found"

      it "should update location" $ do
        db <- newDatabase
        let oldLocation = locationFactory 100 "Old Name"
        insertLocation db oldLocation
        let newLocation = locationFactory 100 "New Name"
        result <- updateLocation db 100 newLocation
        result `shouldBe` True

      it "should delete location" $ do
        db <- newDatabase
        let location = locationFactory 300 "To Delete"
        insertLocation db location
        countBefore <- countLocations db
        result <- deleteLocation db 300
        result `shouldBe` True
        countAfter <- countLocations db
        countAfter `shouldBe` (countBefore - 1)

    -- Stock operations
    describe "Stock operations" $ do
      it "should query stock by location" $ do
        db <- newDatabase
        stockByLoc <- queryStockByLocation db 1
        length stockByLoc `shouldBe` 2  -- Based on test data

      it "should query stock by goods" $ do
        db <- newDatabase
        stockByGood <- queryStockByGood db 1
        length stockByGood `shouldBe` 1

      it "should calculate available stock" $ do
        db <- newDatabase
        available <- queryAvailableStock db 1 1
        case available of
          Just qty -> qty `shouldBe` 90.0  -- 100 - 10
          Nothing -> fail "Stock not found"

      it "should update stock quantities" $ do
        db <- newDatabase
        let newStock = stockFactory 1 1 1 150.0 15.0
        result <- updateStock db 1 newStock
        result `shouldBe` True

      it "should insert stock records" $ do
        db <- newDatabase
        clearDatabase db
        let stock = stockFactory 500 10 1 100.0 10.0
        insertStock db stock
        count <- countStock db
        count `shouldBe` 1

    -- Multi-entity operations
    describe "Multi-entity operations" $ do
      it "should create a realistic scenario" $ do
        db <- createRealisticScenario
        personsCount <- countPersons db
        goodsCount <- countGoods db
        locsCount <- countLocations db
        stockCount <- countStock db
        personsCount `shouldBe` 3
        goodsCount `shouldBe` 10
        locsCount `shouldBe` 2
        stockCount `shouldBe` 5

      it "should find stock for specific good at specific location" $ do
        db <- createRealisticScenario
        stock <- queryAvailableStock db 1 1
        case stock of
          Just qty -> qty `shouldBe` 90.0
          Nothing -> fail "Stock not found"

      it "should query all goods at one location" $ do
        db <- createRealisticScenario
        stocksAtLoc1 <- queryStockByLocation db 1
        length stocksAtLoc1 `shouldBe` 3

    -- Database cleanup
    describe "Database cleanup" $ do
      it "should clear all persons" $ do
        db <- newDatabase
        cleanPersons db
        count <- countPersons db
        count `shouldBe` 0

      it "should clear all goods" $ do
        db <- newDatabase
        cleanGoods db
        count <- countGoods db
        count `shouldBe` 0

      it "should clear all locations" $ do
        db <- newDatabase
        cleanLocations db
        count <- countLocations db
        count `shouldBe` 0

      it "should clear all stock" $ do
        db <- newDatabase
        cleanStock db
        count <- countStock db
        count `shouldBe` 0

      it "should clear entire database" $ do
        db <- createRealisticScenario
        clearDatabase db
        personsCount <- countPersons db
        goodsCount <- countGoods db
        locsCount <- countLocations db
        stockCount <- countStock db
        personsCount `shouldBe` 0
        goodsCount `shouldBe` 0
        locsCount `shouldBe` 0
        stockCount `shouldBe` 0

    -- Error handling
    describe "Error handling" $ do
      it "should return False when updating non-existent person" $ do
        db <- newDatabase
        let person = personFactory 9999 "Ghost"
        result <- updatePerson db 9999 person
        result `shouldBe` False

      it "should return False when updating non-existent goods" $ do
        db <- newDatabase
        let goods = goodsFactory 9999 "Ghost"
        result <- updateGoods db 9999 goods
        result `shouldBe` False

      it "should return False when deleting non-existent person" $ do
        db <- newDatabase
        result <- deletePerson db 9999
        result `shouldBe` False

      it "should return Nothing when finding non-existent person" $ do
        db <- newDatabase
        person <- findPersonById db 9999
        person `shouldBe` Nothing

      it "should return Nothing when finding non-existent goods" $ do
        db <- newDatabase
        goods <- findGoodsById db 9999
        goods `shouldBe` Nothing
