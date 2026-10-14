{-# LANGUAGE OverloadedStrings #-}

module DAL.Fixtures where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (fromGregorian, Day)
import qualified Data.IORef as Data.IORef
import DAL.DB

-- | Factory function for creating test persons
personFactory :: Int64 -> String -> Person
personFactory id name = PersonStub
  { pId = id
  , pCode = Just (T.pack $ "P" ++ show id)
  , pName = T.pack name
  , pINN = Just (T.pack $ "INN" ++ show id)
  , pKPP = Just (T.pack $ "KPP" ++ show id)
  , pPersonType = if id `mod` 2 == 0 then 1 else 2
  , pStatus = 0
  }

-- | Factory function for creating test goods
goodsFactory :: Int64 -> String -> Goods
goodsFactory id name = GoodsStub
  { gId = id
  , gCode = Just (T.pack $ "G" ++ show id)
  , gName = T.pack name
  , gBarcode = Just (T.pack $ "BAR" ++ show id)
  , gUnitId = 1
  , gParentId = Nothing
  }

-- | Factory function for creating test locations
locationFactory :: Int64 -> String -> Location
locationFactory id name = LocationStub
  { lId = id
  , lCode = Just (T.pack $ "L" ++ show id)
  , lName = T.pack name
  , lType = if id `mod` 2 == 0 then 1 else 2
  }

-- | Factory function for creating test stock
stockFactory :: Int64 -> Int64 -> Int64 -> Double -> Double -> Stock
stockFactory id goodId locId qty resrvQty = StockStub
  { sId = id
  , sGoodsId = goodId
  , sLocationId = locId
  , sQtty = qty
  , sResrvQtty = resrvQty
  }

-- | Factory function for creating test bills
billFactory :: Int64 -> Int64 -> Double -> Bill
billFactory id personId total = BillStub
  { billId = id
  , billTotal = total
  }

-- | Create multiple test persons
createTestPersons :: Int -> [Person]
createTestPersons n = [personFactory i ("Person " ++ show i) | i <- [1..fromIntegral n]]

-- | Create multiple test goods
createTestGoods :: Int -> [Goods]
createTestGoods n = [goodsFactory i ("Good " ++ show i) | i <- [1..fromIntegral n]]

-- | Create multiple test locations
createTestLocations :: Int -> [Location]
createTestLocations n = [locationFactory i ("Location " ++ show i) | i <- [1..fromIntegral n]]

-- | Create a realistic test scenario
-- This creates: 3 companies, 10 products, 2 warehouses, and stock records
createRealisticScenario :: IO Database
createRealisticScenario = do
  db <- newDatabase

  -- Create persons (companies)
  mapM_ (insertPerson db) [
    personFactory 1 "Company A",
    personFactory 2 "Company B",
    personFactory 3 "Supplier X"
    ]

  -- Create goods
  mapM_ (insertGoods db) (createTestGoods 10)

  -- Create locations
  mapM_ (insertLocation db) [
    locationFactory 1 "Main Warehouse",
    locationFactory 2 "Branch Warehouse"
    ]

  -- Create stock records
  mapM_ (insertStock db) [
    stockFactory 1 1 1 100.0 10.0,
    stockFactory 2 2 1 50.0 5.0,
    stockFactory 3 3 2 200.0 20.0,
    stockFactory 4 4 2 75.0 7.0,
    stockFactory 5 5 1 300.0 30.0
    ]

  return db

-- | Cleanup utilities
cleanPersons :: Database -> IO ()
cleanPersons db = do
  persons <- readIORef (dbPersons db)
  mapM_ (deletePerson db . pId) persons

cleanGoods :: Database -> IO ()
cleanGoods db = do
  goods <- readIORef (dbGoods db)
  mapM_ (deleteGoods db . gId) goods

cleanLocations :: Database -> IO ()
cleanLocations db = do
  locations <- readIORef (dbLocations db)
  mapM_ (deleteLocation db . lId) locations

cleanStock :: Database -> IO ()
cleanStock db = do
  stocks <- readIORef (dbStock db)
  mapM_ (deleteStock db . sId) stocks

cleanAllData :: Database -> IO ()
cleanAllData db = do
  cleanPersons db
  cleanGoods db
  cleanLocations db
  cleanStock db
  cleanBills db
  where
    cleanBills db = do
      bills <- readIORef (dbBills db)
      mapM_ (deleteBill db . billId) bills

-- | Read from IORef helpers (re-export with better names)
readIORef :: IORef a -> IO a
readIORef = Data.IORef.readIORef
