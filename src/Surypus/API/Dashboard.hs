{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Dashboard (
    DashboardKPI (..),
    RevenuePoint (..),
    OrderStatus (..),
    StockSummary (..),
    getDashboardKPI,
    getRevenueTrend,
    getOrderStatuses,
    getStockSummary,
) where

import Control.Monad.IO.Class (liftIO)
import DAL.Types (QueryResult (..))
import Data.Aeson (ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Sql (ConnectionPool, rawSql, runSqlPool, Single (..))
import GHC.Generics (Generic)

data DashboardKPI = DashboardKPI
    { kpiRevenue :: !Double
    , kpiOrders :: !Int64
    , kpiActiveGoods :: !Int64
    , kpiPartners :: !Int64
    }
    deriving (Show, Eq, Generic)

instance ToJSON DashboardKPI

data RevenuePoint = RevenuePoint
    { rpMonth :: !Text
    , rpRevenue :: !Double
    , rpCount :: !Int64
    }
    deriving (Show, Eq, Generic)

instance ToJSON RevenuePoint

data OrderStatus = OrderStatus
    { osStatus :: !Text
    , osCount :: !Int64
    , osTotal :: !Double
    }
    deriving (Show, Eq, Generic)

instance ToJSON OrderStatus

data StockSummary = StockSummary
    { ssTotalGoods :: !Int64
    , ssActiveGoods :: !Int64
    , ssCategories :: !Int64
    }
    deriving (Show, Eq, Generic)

instance ToJSON StockSummary

getDashboardKPI :: ConnectionPool -> IO (QueryResult DashboardKPI)
getDashboardKPI pool = do
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT \
            \  COALESCE((SELECT SUM(total_amount) FROM bills WHERE status = 'POSTED'), 0), \
            \  COALESCE((SELECT COUNT(*) FROM bills), 0), \
            \  COALESCE((SELECT COUNT(*) FROM goods WHERE is_active), 0), \
            \  COALESCE((SELECT COUNT(*) FROM persons), 0)"
            []) pool
    case result of
        [(Single rev, Single ord, Single goods, Single parts)] ->
            return $ QuerySuccess (DashboardKPI rev ord goods parts)
        _ -> return $ QuerySuccess (DashboardKPI 0 0 0 0)

getRevenueTrend :: ConnectionPool -> IO (QueryResult [RevenuePoint])
getRevenueTrend pool = do
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT \
            \  TO_CHAR(bill_date, 'YYYY-MM'), \
            \  SUM(total_amount), \
            \  COUNT(*) \
            \FROM bills \
            \WHERE bill_date >= NOW() - INTERVAL '12 months' \
            \GROUP BY TO_CHAR(bill_date, 'YYYY-MM') \
            \ORDER BY 1"
            []) pool
    return $ QuerySuccess
        [ RevenuePoint month total count
        | (Single month, Single total, Single count) <- result
        ]

getOrderStatuses :: ConnectionPool -> IO (QueryResult [OrderStatus])
getOrderStatuses pool = do
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT status, COUNT(*), SUM(total_amount) \
            \FROM bills GROUP BY status"
            []) pool
    return $ QuerySuccess
        [ OrderStatus status count total
        | (Single status, Single count, Single total) <- result
        ]

getStockSummary :: ConnectionPool -> IO (QueryResult StockSummary)
getStockSummary pool = do
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT COUNT(*), SUM(CASE WHEN is_active THEN 1 ELSE 0 END), \
            \  COUNT(DISTINCT category_id) \
            \FROM goods"
            []) pool
    case result of
        [(Single total, Single active, Single categories)] ->
            return $ QuerySuccess (StockSummary total active categories)
        _ -> return $ QueryError "Failed to get stock summary"
