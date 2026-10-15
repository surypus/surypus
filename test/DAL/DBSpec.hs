{-# LANGUAGE OverloadedStrings #-}

-- | Tests for DAL.DB module
module DAL.DBSpec (spec) where

import Test.Hspec
import Data.Text (Text)
import qualified Data.Text as T

import DAL.DB

spec :: Spec
spec = do
  describe "DAL.DB - In-Memory Database" $ do

    describe "Person Operations" $ do
      it "should create a new database" $ do
        db <- newDatabase
        persons <- queryPersons db 10 0
        length persons `shouldBe` 3

      it "should find person by ID" $ do
        db <- newDatabase
        result <- findPersonById db 1
        case result of
          Just p -> pName p `shouldBe` T.pack "Company A"
          Nothing -> fail "Should find person with ID 1"

      it "should query persons with pagination" $ do
        db <- newDatabase
        page1 <- queryPersons db 2 0
        page2 <- queryPersons db 2 2
        length page1 `shouldBe` 2
        length page2 `shouldBe` 1

      it "should insert new person" $ do
        db <- newDatabase
        let newPerson = PersonStub
              { pId = 999
              , pCode = Just "P999"
              , pName = T.pack "New Company"
              , pINN = Just "9999999999"
              , pKPP = Just "999999999"
              , pPersonType = 1
              , pStatus = 1
              }
        insertPerson db newPerson
        found <- findPersonById db 999
        case found of
          Just p -> pName p `shouldBe` T.pack "New Company"
          Nothing -> fail "Should find inserted person"

      it "should update person" $ do
        db <- newDatabase
        found <- findPersonById db 1
        case found of
          Just person -> do
            let updated = person { pName = T.pack "Updated Name" }
            _ <- updatePerson db 1 updated
            result <- findPersonById db 1
            case result of
              Just p -> pName p `shouldBe` T.pack "Updated Name"
              Nothing -> fail "Should find updated person"
          Nothing -> fail "Should find person to update"

      it "should delete person" $ do
        db <- newDatabase
        insertPerson db (PersonStub 999 (Just "P999") (T.pack "Temp") Nothing Nothing 1 0)
        found1 <- findPersonById db 999
        case found1 of
          Just _ -> do
            _ <- deletePerson db 999
            found2 <- findPersonById db 999
            found2 `shouldBe` Nothing
          Nothing -> fail "Should insert before delete"

    describe "Goods Operations" $ do
      it "should find goods by ID" $ do
        db <- newDatabase
        result <- findGoodsById db 1
        case result of
          Just g -> gName g `shouldBe` T.pack "Product A"
          Nothing -> fail "Should find goods with ID 1"

      it "should query goods with pagination" $ do
        db <- newDatabase
        page1 <- queryGoods db 2 0
        page2 <- queryGoods db 2 2
        length page1 `shouldBe` 2
        length page2 `shouldBe` 1

      it "should insert goods" $ do
        db <- newDatabase
        let newGoods = GoodsStub
              { gId = 999
              , gCode = Just "G999"
              , gName = T.pack "New Product"
              , gBarcode = Nothing
              , gUnitId = 1
              , gParentId = Nothing
              }
        insertGoods db newGoods
        found <- findGoodsById db 999
        case found of
          Just g -> gName g `shouldBe` T.pack "New Product"
          Nothing -> fail "Should find inserted goods"

      it "should update goods" $ do
        db <- newDatabase
        found <- findGoodsById db 1
        case found of
          Just goods -> do
            let updated = goods { gName = T.pack "Updated Product" }
            _ <- updateGoods db 1 updated
            result <- findGoodsById db 1
            case result of
              Just g -> gName g `shouldBe` T.pack "Updated Product"
              Nothing -> fail "Should find updated goods"
          Nothing -> fail "Should find goods to update"

    describe "Location Operations" $ do
      it "should find location by ID" $ do
        db <- newDatabase
        result <- findLocationById db 1
        case result of
          Just l -> lName l `shouldBe` T.pack "Main Warehouse"
          Nothing -> fail "Should find location with ID 1"

      it "should query locations with pagination" $ do
        db <- newDatabase
        page1 <- queryLocations db 2 0
        page2 <- queryLocations db 2 2
        length page1 `shouldBe` 2
        length page2 `shouldBe` 1

      it "should insert location" $ do
        db <- newDatabase
        let newLoc = LocationStub
              { lId = 999
              , lCode = Just "LOC999"
              , lName = T.pack "New Location"
              , lType = 3
              }
        insertLocation db newLoc
        found <- findLocationById db 999
        case found of
          Just l -> lName l `shouldBe` T.pack "New Location"
          Nothing -> fail "Should find inserted location"

    describe "Stock Operations" $ do
      it "should query stock with pagination" $ do
        db <- newDatabase
        stock <- queryStock db 10 0
        length stock `shouldBe` 3

      it "should insert stock" $ do
        db <- newDatabase
        let newStock = StockStub
              { sId = 999
              , sGoodsId = 1
              , sLocationId = 1
              , sQtty = 50
              , sResrvQtty = 0
              }
        insertStock db newStock
        stock <- queryStock db 100 0
        length stock `shouldBe` 4

      it "should update stock quantity" $ do
        db <- newDatabase
        _ <- updateStock db 1 (StockStub 1 1 1 150 0)
        stock <- queryStock db 10 0
        case filter (\s -> sId s == 1) stock of
          (s:_) -> sQtty s `shouldBe` 150
          [] -> fail "Should find stock with ID 1"

    describe "Bill Operations" $ do
      it "should insert bill" $ do
        db <- newDatabase
        let newBill = BillStub 999 5000.0 "USD" 1.0
        insertBill db newBill
        bills <- queryBills db 10 0
        length bills `shouldBe` 2

      it "should query bills with pagination" $ do
        db <- newDatabase
        testBills <- queryBills db 10 0
        length testBills `shouldBe` 1
