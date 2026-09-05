-- ============================================================================
-- SURYPUS DATABASE LAYER - Simple In-Memory Implementation
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}

module DAL.DB where
import qualified Data.List as L

import Data.IORef (IORef, newIORef, readIORef, modifyIORef, modifyIORef', writeIORef)
import Data.Int (Int64)
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T

-- ============================================================================
-- IN-MEMORY STORAGE - Using compatible stub types
-- ============================================================================

-- Заглушки для типов (заменить на реальные типы из DAL.Types когда они будут определены)
data Person = PersonStub
  { pId :: Int64
  , pCode :: Maybe Text
  , pName :: Text
  , pINN :: Maybe Text
  , pKPP :: Maybe Text
  , pPersonType :: Int
  , pStatus :: Int
  } deriving (Show, Eq)

data Goods = GoodsStub
  { gId :: Int64
  , gCode :: Maybe Text
  , gName :: Text
  , gBarcode :: Maybe Text
  , gUnitId :: Int
  , gParentId :: Maybe Int64
  } deriving (Show, Eq)

data Location = LocationStub
  { lId :: Int64
  , lCode :: Maybe Text
  , lName :: Text
  , lType :: Int
  } deriving (Show, Eq)

data Bill = BillStub
  { billId :: Int64
  , billTotal :: Double
  , billCurrencyId :: Text
  , billExchangeRate :: Double
  } deriving (Show, Eq)

data Stock = StockStub
  { sId :: Int64
  , sGoodsId :: Int64
  , sLocationId :: Int64
  , sQtty :: Double
  , sResrvQtty :: Double
  } deriving (Show, Eq)

data Database = Database
  { dbPersons :: IORef [Person],
    dbGoods :: IORef [Goods],
    dbLocations :: IORef [Location],
    dbBills :: IORef [Bill],
    dbStock :: IORef [Stock]
  }

-- Create initial database
newDatabase :: IO Database
newDatabase = do
  persons <- newIORef testPersons
  goods <- newIORef testGoods
  locations <- newIORef testLocations
  bills <- newIORef testBills
  stock <- newIORef testStock
  pure Database {dbPersons = persons, dbGoods = goods, dbLocations = locations, dbBills = bills, dbStock = stock}

-- Test data - using record syntax
testPersons :: [Person]
testPersons =
  [ PersonStub {pId = 1, pCode = Just "001", pName = T.pack "Company A", pINN = Just "1234567891", pKPP = Just "123456791", pPersonType = 1, pStatus = 0},
    PersonStub {pId = 2, pCode = Just "002", pName = T.pack "Company B", pINN = Just "1234567892", pKPP = Just "123456792", pPersonType = 1, pStatus = 0},
    PersonStub {pId = 3, pCode = Just "003", pName = T.pack "Supplier X", pINN = Just "1234567893", pKPP = Just "123456793", pPersonType = 2, pStatus = 0}
  ]

testGoods :: [Goods]
testGoods =
  [ GoodsStub {gId = 1, gCode = Just "001", gName = T.pack "Product A", gBarcode = Just "1234567890123", gUnitId = 1, gParentId = Nothing},
    GoodsStub {gId = 2, gCode = Just "002", gName = T.pack "Product B", gBarcode = Just "1234567890124", gUnitId = 1, gParentId = Nothing},
    GoodsStub {gId = 3, gCode = Just "003", gName = T.pack "Product C", gBarcode = Just "1234567890125", gUnitId = 1, gParentId = Nothing}
  ]

testLocations :: [Location]
testLocations =
  [ LocationStub {lId = 1, lCode = Just "WH-01", lName = T.pack "Main Warehouse", lType = 1},
    LocationStub {lId = 2, lCode = Just "WH-02", lName = T.pack "Second Warehouse", lType = 1},
    LocationStub {lId = 3, lCode = Just "SHOP-01", lName = T.pack "Retail Shop", lType = 2}
  ]

testBills :: [Bill]
testBills =
  [ BillStub { billId = 1, billTotal = 100.0, billCurrencyId = "RUB", billExchangeRate = 1.0 }
  ]

testStock :: [Stock]
testStock =
  [ StockStub {sId = 1, sGoodsId = 1, sLocationId = 1, sQtty = 100.0, sResrvQtty = 0.0},
    StockStub {sId = 2, sGoodsId = 2, sLocationId = 1, sQtty = 50.0, sResrvQtty = 0.0},
    StockStub {sId = 3, sGoodsId = 1, sLocationId = 2, sQtty = 200.0, sResrvQtty = 0.0}
  ]

-- ============================================================================
-- DB ACTIONS
-- ============================================================================

-- Persons
queryPersons :: Database -> Int -> Int -> IO [Person]
queryPersons db limit offset = do
  ps <- readIORef (dbPersons db)
  return $ drop offset $ take limit ps

-- Goods
queryGoods :: Database -> Int -> Int -> IO [Goods]
queryGoods db limit offset = do
  gs <- readIORef (dbGoods db)
  return $ drop offset $ take limit gs

-- Locations
queryLocations :: Database -> Int -> Int -> IO [Location]
queryLocations db limit offset = do
  ls <- readIORef (dbLocations db)
  return $ drop offset $ take limit ls

-- Bills
queryBills :: Database -> Int -> Int -> IO [Bill]
queryBills db limit offset = do
  bs <- readIORef (dbBills db)
  return $ drop offset $ take limit bs

-- Stock
queryStock :: Database -> Int -> Int -> IO [Stock]
queryStock db limit offset = do
  st <- readIORef (dbStock db)
  return $ drop offset $ take limit st

-- Find operations
findPersonById :: Database -> Int64 -> IO (Maybe Person)
findPersonById db pid = do
  ps <- readIORef (dbPersons db)
  return $ find (\p -> pId p == pid) ps

findGoodsById :: Database -> Int64 -> IO (Maybe Goods)
findGoodsById db gid = do
  gs <- readIORef (dbGoods db)
  return $ find (\g -> gId g == gid) gs

findLocationById :: Database -> Int64 -> IO (Maybe Location)
findLocationById db lid = do
  ls <- readIORef (dbLocations db)
  return $ find (\l -> lId l == lid) ls

-- | Insert operations
insertPerson :: Database -> Person -> IO ()
insertPerson db p = modifyIORef (dbPersons db) (p :)

insertGoods :: Database -> Goods -> IO ()
insertGoods db g = modifyIORef (dbGoods db) (g :)

insertLocation :: Database -> Location -> IO ()
insertLocation db l = modifyIORef (dbLocations db) (l :)

insertBill :: Database -> Bill -> IO ()
insertBill db b = modifyIORef (dbBills db) (b :)

insertStock :: Database -> Stock -> IO ()
insertStock db s = modifyIORef (dbStock db) (s :)

-- | Update operations
updatePerson :: Database -> Int64 -> Person -> IO Bool
updatePerson db pid newPerson = do
  ps <- readIORef (dbPersons db)
  case find (\p -> pId p == pid) ps of
    Just _ -> do
      let updated = map (\p -> if pId p == pid then newPerson else p) ps
      writeIORef (dbPersons db) updated
      return True
    Nothing -> return False

updateGoods :: Database -> Int64 -> Goods -> IO Bool
updateGoods db gid newGoods = do
  gs <- readIORef (dbGoods db)
  case find (\g -> gId g == gid) gs of
    Just _ -> do
      let updated = map (\g -> if gId g == gid then newGoods else g) gs
      writeIORef (dbGoods db) updated
      return True
    Nothing -> return False

updateLocation :: Database -> Int64 -> Location -> IO Bool
updateLocation db lid newLocation = do
  ls <- readIORef (dbLocations db)
  case find (\l -> lId l == lid) ls of
    Just _ -> do
      let updated = map (\l -> if lId l == lid then newLocation else l) ls
      writeIORef (dbLocations db) updated
      return True
    Nothing -> return False

updateStock :: Database -> Int64 -> Stock -> IO Bool
updateStock db sid newStock = do
  st <- readIORef (dbStock db)
  case find (\s -> sId s == sid) st of
    Just _ -> do
      let updated = map (\s -> if sId s == sid then newStock else s) st
      writeIORef (dbStock db) updated
      return True
    Nothing -> return False

-- | Delete operations
deletePerson :: Database -> Int64 -> IO Bool
deletePerson db pid = do
  ps <- readIORef (dbPersons db)
  case find (\p -> pId p == pid) ps of
    Just _ -> do
      let remaining = filter (\p -> pId p /= pid) ps
      writeIORef (dbPersons db) remaining
      return True
    Nothing -> return False

deleteGoods :: Database -> Int64 -> IO Bool
deleteGoods db gid = do
  gs <- readIORef (dbGoods db)
  case find (\g -> gId g == gid) gs of
    Just _ -> do
      let remaining = filter (\g -> gId g /= gid) gs
      writeIORef (dbGoods db) remaining
      return True
    Nothing -> return False

deleteLocation :: Database -> Int64 -> IO Bool
deleteLocation db lid = do
  ls <- readIORef (dbLocations db)
  case find (\l -> lId l == lid) ls of
    Just _ -> do
      let remaining = filter (\l -> lId l /= lid) ls
      writeIORef (dbLocations db) remaining
      return True
    Nothing -> return False

deleteBill :: Database -> Int64 -> IO Bool
deleteBill db bid = do
  bs <- readIORef (dbBills db)
  case find (\b -> billId b == bid) bs of
    Just _ -> do
      let remaining = filter (\b -> billId b /= bid) bs
      writeIORef (dbBills db) remaining
      return True
    Nothing -> return False

deleteStock :: Database -> Int64 -> IO Bool
deleteStock db sid = do
  st <- readIORef (dbStock db)
  case find (\s -> sId s == sid) st of
    Just _ -> do
      let remaining = filter (\s -> sId s /= sid) st
      writeIORef (dbStock db) remaining
      return True
    Nothing -> return False

-- | Filtered query operations
queryPersonsByType :: Database -> Int -> IO [Person]
queryPersonsByType db ptype = do
  ps <- readIORef (dbPersons db)
  return $ filter (\p -> pPersonType p == ptype) ps

queryGoodsByCategory :: Database -> Int -> IO [Goods]
queryGoodsByCategory db catId = do
  gs <- readIORef (dbGoods db)
  return $ filter (\g -> case gId g of _ -> True) gs  -- Simplified

queryStockByLocation :: Database -> Int64 -> IO [Stock]
queryStockByLocation db locId = do
  st <- readIORef (dbStock db)
  return $ filter (\s -> sLocationId s == locId) st

queryStockByGood :: Database -> Int64 -> IO [Stock]
queryStockByGood db goodId = do
  st <- readIORef (dbStock db)
  return $ filter (\s -> sGoodsId s == goodId) st

queryAvailableStock :: Database -> Int64 -> Int64 -> IO (Maybe Double)
queryAvailableStock db goodId locId = do
  st <- readIORef (dbStock db)
  case find (\s -> sGoodsId s == goodId && sLocationId s == locId) st of
    Just s -> return $ Just (sQtty s - sResrvQtty s)
    Nothing -> return Nothing

-- | Count operations
countPersons :: Database -> IO Int
countPersons db = length <$> readIORef (dbPersons db)

countGoods :: Database -> IO Int
countGoods db = length <$> readIORef (dbGoods db)

countLocations :: Database -> IO Int
countLocations db = length <$> readIORef (dbLocations db)

countBills :: Database -> IO Int
countBills db = length <$> readIORef (dbBills db)

countStock :: Database -> IO Int
countStock db = length <$> readIORef (dbStock db)

-- | Clear all data (for testing)
clearDatabase :: Database -> IO ()
clearDatabase db = do
  writeIORef (dbPersons db) []
  writeIORef (dbGoods db) []
  writeIORef (dbLocations db) []
  writeIORef (dbBills db) []
  writeIORef (dbStock db) []
