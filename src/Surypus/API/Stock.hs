{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.Stock
  ( getLowStock
  , getStockSummary
  , getValuation
  , LowStockAlert(..)
  , StockSummary(..)
  , StockValuationRow(..)
  ) where

import Control.Monad.IO.Class (liftIO)
import DAL.Pool (ConnectionPool)
import qualified DAL.Queries as Q
import DAL.Types (Goods(..), QueryResult(..))
import Data.Aeson (ToJSON, FromJSON)
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import GHC.Generics (Generic)
import Database.Persist.Sql (runSqlPool, rawSql, Single(..))

data LowStockAlert = LowStockAlert
  { lsaGoodsId :: Int64
  , lsaGoodsName :: Text
  , lsaGoodsCode :: Maybe Text
  , lsaCurrentStock :: Double
  , lsaMinLevel :: Double
  , lsaSeverity :: Text
  } deriving (Show, Eq, Generic)
instance ToJSON LowStockAlert
instance FromJSON LowStockAlert

data StockSummary = StockSummary
  { ssTotalItems :: Double
  , ssLowStockCount :: Int
  } deriving (Show, Eq, Generic)
instance ToJSON StockSummary
instance FromJSON StockSummary

data StockValuationRow = StockValuationRow
  { svrGoodsId :: Int64
  , svrGoodsName :: Text
  , svrGoodsCode :: Maybe Text
  , svrQuantity :: Double
  , svrCost :: Double
  , svrTotalValue :: Double
  } deriving (Show, Eq, Generic)
instance ToJSON StockValuationRow
instance FromJSON StockValuationRow

getLowStock :: ConnectionPool -> IO (QueryResult [LowStockAlert])
getLowStock pool = do
  result <- Q.getLowStockGoods pool
  case result of
    QuerySuccess goods -> do
      let alerts = map goodsToAlert goods
      return $ QuerySuccess alerts
    QueryError err -> return $ QueryError err
  where
    goodsToAlert g = LowStockAlert
      (goodsId g)
      (goodsName g)
      (goodsCode g)
      (fromMaybe 0 (goodsMinStock g) * 2)
      (fromMaybe 0 (goodsMinStock g))
      "warning"

getStockSummary :: ConnectionPool -> IO (QueryResult StockSummary)
getStockSummary pool = do
  let sql = "SELECT COALESCE(SUM(qtty), 0), COUNT(*) FILTER (WHERE qtty < 10) FROM stock" :: Text
  result <- (liftIO $ runSqlPool (rawSql sql []) pool) :: IO [(Single Double, Single Int)]
  case result of
    [(Single total, Single low)] -> return $ QuerySuccess (StockSummary total low)
    _ -> return $ QuerySuccess (StockSummary 0 0)

getValuation :: ConnectionPool -> IO (QueryResult [StockValuationRow])
getValuation pool = do
  -- Use lots table for actual FIFO-weighted average valuation
  -- Total value = quantity * average cost from lots
  let sql = "SELECT g.id, g.name, g.code, \
            \COALESCE(SUM(l.rest), 0) as total_qty, \
            \COALESCE(AVG(l.cost), 0) as avg_cost, \
            \(COALESCE(SUM(l.rest), 0) * COALESCE(AVG(l.cost), 0)) as total_value \
            \FROM goods g \
            \LEFT JOIN lot l ON g.id = l.goods_id \
            \GROUP BY g.id, g.name, g.code \
            \ORDER BY g.name" :: Text
  result <- (liftIO $ runSqlPool (rawSql sql []) pool) 
    :: IO [(Single Int64, Single Text, Single (Maybe Text), Single Double, Single Double, Single Double)]
  let rows = map (\(Single gid, Single gn, Single gc, Single qty, Single cost, Single total) ->
        StockValuationRow gid gn gc qty cost total) result
  return $ QuerySuccess rows
