{-# LANGUAGE OverloadedStrings #-}

module DAL.Procedures where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import DAL.Types (QueryResult(..))
import Database.Persist.Sql (ConnectionPool, PersistValue (..), rawSql, runSqlPool, Single (..))
import Surypus.CoreTypes (Decimal (..))

calcStockBalance :: ConnectionPool -> Int64 -> Int64 -> IO (QueryResult Decimal)
calcStockBalance pool goodsId locationId = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT calc_stock_balance(?, ?)" [PersistInt64 goodsId, PersistInt64 locationId]) pool
    case result of
        [Single n] -> return $ QuerySuccess (Decimal (realToFrac (n :: Double)))
        _ -> return $ QueryError "calc_stock_balance failed"

getLotBounds :: ConnectionPool -> Int64 -> Int64 -> IO (QueryResult (Maybe (Text, Text, Decimal)))
getLotBounds pool goodsId locationId = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT min_date::text, max_date::text, total_qty FROM get_lot_bounds(?, ?)"
            [PersistInt64 goodsId, PersistInt64 locationId]) pool
    case result of
        [(Single md, Single mxd, Single tq)] -> return $ QuerySuccess (Just (md, mxd, Decimal (realToFrac (tq :: Double))))
        _ -> return $ QuerySuccess Nothing

calcVAT :: ConnectionPool -> Double -> Double -> IO (QueryResult Double)
calcVAT pool amount rate = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT calc_vat(?, ?)" [PersistDouble amount, PersistDouble rate]) pool
    case result of
        [Single v] -> return $ QuerySuccess v
        _ -> return $ QueryError "calc_vat failed"

calcVATInclusive :: ConnectionPool -> Double -> Double -> IO (QueryResult Double)
calcVATInclusive pool amount rate = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT calc_vat_inclusive(?, ?)" [PersistDouble amount, PersistDouble rate]) pool
    case result of
        [Single v] -> return $ QuerySuccess v
        _ -> return $ QueryError "calc_vat_inclusive failed"

calcPriceWithoutVAT :: ConnectionPool -> Double -> Double -> IO (QueryResult Double)
calcPriceWithoutVAT pool amount rate = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT calc_price_without_vat(?, ?)" [PersistDouble amount, PersistDouble rate]) pool
    case result of
        [Single v] -> return $ QuerySuccess v
        _ -> return $ QueryError "calc_price_without_vat failed"

postBill :: ConnectionPool -> Int64 -> IO (QueryResult Bool)
postBill pool billId = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT post_bill(?)" [PersistInt64 billId]) pool
    case result of
        [Single v] -> return $ QuerySuccess v
        _ -> return $ QueryError "post_bill failed"

cancelBill :: ConnectionPool -> Int64 -> IO (QueryResult Bool)
cancelBill pool billId = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT cancel_bill(?)" [PersistInt64 billId]) pool
    case result of
        [Single v] -> return $ QuerySuccess v
        _ -> return $ QueryError "cancel_bill failed"

validateDoubleEntry :: ConnectionPool -> Int64 -> IO (QueryResult Bool)
validateDoubleEntry pool entryId = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT validate_double_entry(?)" [PersistInt64 entryId]) pool
    case result of
        [Single v] -> return $ QuerySuccess v
        _ -> return $ QueryError "validate_double_entry failed"

calcAccountBalance :: ConnectionPool -> Int64 -> IO (QueryResult Decimal)
calcAccountBalance pool accountId = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT calc_account_balance(?)" [PersistInt64 accountId]) pool
    case result of
        [Single n] -> return $ QuerySuccess (Decimal (realToFrac (n :: Double)))
        _ -> return $ QueryError "calc_account_balance failed"

getSalesReport :: ConnectionPool -> Text -> Text -> IO (QueryResult [(Text, Double)])
getSalesReport pool dateFrom dateTo = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT report_date::text, total_amount FROM get_sales_report(?, ?)"
            [PersistText dateFrom, PersistText dateTo]) pool
    let converted = map (\(Single d, Single a) -> (d, a)) result
    return $ QuerySuccess converted
