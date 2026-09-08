{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Queries where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Database.Esqueleto.Experimental
import Database.Persist.Sql (ConnectionPool, Entity, runSqlPool, toSqlKey, rawSql)
import DAL.Schema
import DAL.Types
import DAL.Conversion
import qualified DAL.QueriesORM as ORM

-- | Delegated functions (forwarded to DAL.QueriesORM)

getPersons :: ConnectionPool -> IO (QueryResult [Person])
getPersons = ORM.getPersons

searchPersons :: ConnectionPool -> Text -> IO (QueryResult [Person])
searchPersons = ORM.searchPersons

getPersonById :: ConnectionPool -> Int64 -> IO (QueryResult Person)
getPersonById = ORM.getPersonById

getGoods :: ConnectionPool -> IO (QueryResult [Goods])
getGoods = ORM.getGoods

searchGoods :: ConnectionPool -> Text -> IO (QueryResult [Goods])
searchGoods = ORM.searchGoods

getGoodsById :: ConnectionPool -> Int64 -> IO (QueryResult Goods)
getGoodsById = ORM.getGoodsById

getGoodsByBarcode :: ConnectionPool -> Text -> IO (QueryResult Goods)
getGoodsByBarcode = ORM.getGoodsByBarcode

getLocations :: ConnectionPool -> IO (QueryResult [Location])
getLocations = ORM.getLocations

getLocationById :: ConnectionPool -> Int64 -> IO (QueryResult Location)
getLocationById = ORM.getLocationById

getBills :: ConnectionPool -> IO (QueryResult [Bill])
getBills = ORM.getBills

getBillById :: ConnectionPool -> Int64 -> IO (QueryResult Bill)
getBillById = ORM.getBillById

getBillLines :: ConnectionPool -> Int64 -> IO (QueryResult [BillLine])
getBillLines = ORM.getBillLines

getStockAll :: ConnectionPool -> IO (QueryResult [Stock])
getStockAll = ORM.getStockAll

getStockMovements :: ConnectionPool -> IO (QueryResult [StockMovement])
getStockMovements = ORM.getStockMovements

getStockMovementsByGoods :: ConnectionPool -> Int64 -> IO (QueryResult [StockMovement])
getStockMovementsByGoods = ORM.getStockMovementsByGoods

getStockByLocation :: ConnectionPool -> Int64 -> IO (QueryResult [Stock])
getStockByLocation = ORM.getStockByLocation

getStockByGoods :: ConnectionPool -> Int64 -> IO (QueryResult [Stock])
getStockByGoods = ORM.getStockByGoods

getUsers :: ConnectionPool -> IO (QueryResult [User])
getUsers = ORM.getUsers

getEmployees :: ConnectionPool -> IO (QueryResult [Employee])
getEmployees = ORM.getEmployees

getSalaries :: ConnectionPool -> IO (QueryResult [Salary])
getSalaries = ORM.getSalaries

getAccPlans :: ConnectionPool -> IO (QueryResult [AccPlan])
getAccPlans = ORM.getAccPlans

getAccTurns :: ConnectionPool -> IO (QueryResult [AccTurn])
getAccTurns = ORM.getAccTurns

getPayments :: ConnectionPool -> IO (QueryResult [Payment])
getPayments = ORM.getPayments

getUnits :: ConnectionPool -> IO (QueryResult [Unit])
getUnits = ORM.getUnits

getTaxes :: ConnectionPool -> IO (QueryResult [Tax])
getTaxes = ORM.getTaxes

getDocumentTypes :: ConnectionPool -> IO (QueryResult [DocumentRegisterType])
getDocumentTypes = ORM.getDocumentTypes

getOrders :: ConnectionPool -> IO (QueryResult [Order])
getOrders = ORM.getOrders

getGoodsPrices :: ConnectionPool -> IO (QueryResult [GoodsPrice])
getGoodsPrices = ORM.getGoodsPrices

getReports :: ConnectionPool -> IO (QueryResult [ReportTemplate])
getReports = ORM.getReports

getCurrencies :: ConnectionPool -> IO (QueryResult [Currency])
getCurrencies = ORM.getCurrencies

-- | Functions without ORM equivalents — inline esqueleto

getPaymentById :: ConnectionPool -> Int64 -> IO (QueryResult Payment)
getPaymentById pool pid = do
    result <- liftIO $ runSqlPool
        (select $ do
            p <- from $ table @PaymentEntity
            where_ $ p ^. PaymentEntityId ==. val (toSqlKey pid)
            return p
        ) pool
    return $ case result of
        (entity:_) -> QuerySuccess (paymentFromEntity entity)
        _ -> QueryError "Not Found"

getTaxById :: ConnectionPool -> Int64 -> IO (QueryResult Tax)
getTaxById pool tid = do
    result <- liftIO $ runSqlPool
        (select $ do
            t <- from $ table @TaxEntity
            where_ $ t ^. TaxEntityId ==. val (toSqlKey tid)
            return t
        ) pool
    return $ case result of
        (entity:_) -> QuerySuccess (taxFromEntity entity)
        _ -> QueryError "Not Found"

getAccPlanById :: ConnectionPool -> Int64 -> IO (QueryResult AccPlan)
getAccPlanById pool pid = do
    result <- liftIO $ runSqlPool
        (select $ do
            a <- from $ table @AccPlanEntity
            where_ $ a ^. AccPlanEntityId ==. val (toSqlKey pid)
            return a
        ) pool
    return $ case result of
        (entity:_) -> QuerySuccess (accPlanFromEntity entity)
        _ -> QueryError "Not Found"

getEmployeeById :: ConnectionPool -> Int64 -> IO (QueryResult Employee)
getEmployeeById pool eid = do
    result <- liftIO $ runSqlPool
        (select $ do
            e <- from $ table @EmployeeEntity
            where_ $ e ^. EmployeeEntityId ==. val (toSqlKey eid)
            return e
        ) pool
    return $ case result of
        (entity:_) -> QuerySuccess (employeeFromEntity entity)
        _ -> QueryError "Not Found"

getSalaryByEmployee :: ConnectionPool -> Int64 -> IO (QueryResult [Salary])
getSalaryByEmployee pool eid = do
    entities <- liftIO $ runSqlPool
        (select $ do
            s <- from $ table @SalaryEntity
            where_ $ s ^. SalaryEntityEmployeeId ==. val (eid :: Int64)
            orderBy [desc $ s ^. SalaryEntityDate, desc $ s ^. SalaryEntityId]
            return s
        ) pool
    return $ QuerySuccess (map salaryFromEntity entities)

getReportById :: ConnectionPool -> Int64 -> IO (QueryResult ReportTemplate)
getReportById pool rid = do
    result <- liftIO $ runSqlPool
        (select $ do
            r <- from $ table @ReportTemplateEntity
            where_ $ r ^. ReportTemplateEntityId ==. val (toSqlKey rid)
            return r
        ) pool
    return $ case result of
        (entity:_) -> QuerySuccess (ORM.reportTemplateFromEntity entity)
        _ -> QueryError "Not Found"

getPaymentsByBill :: ConnectionPool -> Int64 -> IO (QueryResult [Payment])
getPaymentsByBill pool billId = do
    entities <- liftIO $ runSqlPool
        (select $ do
            p <- from $ table @PaymentEntity
            where_ $ p ^. PaymentEntityBillId ==. val (billId :: Int64)
            orderBy [desc $ p ^. PaymentEntityDate, desc $ p ^. PaymentEntityId]
            return p
        ) pool
    return $ QuerySuccess (map paymentFromEntity entities)

getPaymentsByStatus :: ConnectionPool -> Int -> IO (QueryResult [Payment])
getPaymentsByStatus pool statusVal = do
    entities <- liftIO $ runSqlPool
        (select $ do
            p <- from $ table @PaymentEntity
            where_ $ p ^. PaymentEntityPayStatus ==. val statusVal
            orderBy [desc $ p ^. PaymentEntityDate, desc $ p ^. PaymentEntityId]
            return p
        ) pool
    return $ QuerySuccess (map paymentFromEntity entities)

getLowStockGoods :: ConnectionPool -> IO (QueryResult [Goods])
getLowStockGoods pool = do
    entities <- liftIO $ runSqlPool
        (rawSql
            "SELECT ?? FROM goods g \
            \WHERE g.min_stock IS NOT NULL \
            \  AND (SELECT COALESCE(SUM(s.qtty), 0) FROM stock s WHERE s.goods_id = g.id) <= g.min_stock"
            [])
        pool
    return $ QuerySuccess (map goodsFromEntity entities)
