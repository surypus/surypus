{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | DAL.Queries — read queries used by the API layer.
-- Only the queries the HTTP handlers need live here;
-- list-style queries are implemented in 'DAL.QueriesORM'.
module DAL.Queries
  ( getLowStockGoods
  , getEmployeeById
  , getSalaryByEmployee
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import qualified Data.Text as T
import Database.Esqueleto.Experimental
import Database.Persist.Sql (ConnectionPool, runSqlPool, rawSql, fromSqlKey, PersistValue(..), Single(..))
import Database.Persist.Postgresql (ConnectionPool)
import qualified Database.Persist as P
import qualified Surypus.DB.Schema as DBS
import Surypus.DB.Schema (SalaryEntity(..))
import DAL.Types

-- | Goods whose stock is at or below the minimum level
getLowStockGoods :: ConnectionPool -> IO (QueryResult [Goods])
getLowStockGoods pool = do
  rows <- liftIO $ runSqlPool
    (rawSql
      "SELECT g.id, g.code, g.name, g.min_stock FROM goods g \
      \WHERE g.min_stock IS NOT NULL \
      \  AND (SELECT COALESCE(SUM(s.qtty), 0) FROM stock s WHERE s.goods_id = g.id) <= g.min_stock"
      [])
    pool
  return $ QuerySuccess (map goodsFromRow rows)

goodsFromRow :: (Single Int64, Single (Maybe T.Text), Single T.Text, Single (Maybe T.Text)) -> Goods
goodsFromRow (Single gid, Single gcode, Single gname, Single gmin) = Goods
  { goodsId = fromIntegral gid
  , goodsCode = gcode
  , goodsName = gname
  , goodsFullName = Nothing
  , goodsBarcode = Nothing
  , goodsUnitId = Nothing
  , goodsCategoryId = Nothing
  , goodsType = Nothing
  , goodsStatus = Nothing
  , goodsMinStock = gmin
  , goodsMaxStock = Nothing
  , goodsWeight = Nothing
  , goodsVolume = Nothing
  , goodsCreatedAt = Nothing
  , goodsUpdatedAt = Nothing
  }

-- | One employee by id
getEmployeeById :: ConnectionPool -> Int64 -> IO (QueryResult Employee)
getEmployeeById pool eid = do
  rows <- liftIO $ runSqlPool
    (rawSql
      "SELECT id, code, first_name, last_name FROM employees WHERE id = ?"
      [PersistInt64 eid])
    pool
  return $ case rows of
    (row : _) -> QuerySuccess (employeeFromRow row)
    [] -> QueryError "Employee not found"

employeeFromRow :: (Single Int64, Single T.Text, Single T.Text, Single (Maybe T.Text)) -> Employee
employeeFromRow (Single eid, Single ecode, Single efirst, Single elast) = Employee
  { employeeId = eid
  , employeeCode = ecode
  , employeeFirstName = efirst
  , employeeLastName = elast
  }

-- | Salary records for one employee
getSalaryByEmployee :: ConnectionPool -> Int64 -> IO (QueryResult [Salary])
getSalaryByEmployee pool eid = do
  entities <- liftIO $ runSqlPool
    (select $ do
        s <- from $ table @SalaryEntity
        where_ $ s ^. DBS.SalaryEntityEmployeeId ==. val (eid :: Int64)
        orderBy [desc $ s ^. DBS.SalaryEntityDate, desc $ s ^. DBS.SalaryEntityId]
        return s)
    pool
  return $ QuerySuccess (map salaryFromEntity entities)

salaryFromEntity :: P.Entity SalaryEntity -> Salary
salaryFromEntity (P.Entity key e) = Salary
  { salaryId = fromSqlKey key
  , salaryEmployeeId = salaryEntityEmployeeId e
  , salaryAmount = salaryEntityAmount e
  , salaryPeriod = salaryEntityPeriod e
  }
