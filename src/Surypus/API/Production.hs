{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Production (
    listTechCards,
    createTechCard,
    getTechCard,
    updateTechCard,
    deleteTechCard,
    listWorkOrders,
    createWorkOrder,
    getWorkOrder,
    updateWorkOrder,
    deleteWorkOrder,
    releaseWorkOrder,
    completeWorkOrder,
) where

import Control.Applicative ((<|>))
import Control.Monad.IO.Class (liftIO)
import DAL.Types (QueryResult (..))
import Data.Int (Int16, Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime (..), fromGregorian, secondsToDiffTime)
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Database.Persist.Sql (ConnectionPool, PersistValue (..), rawExecute, rawSql, runSqlPool, Single (..))
import Production.Types (TechCard (..), TechLine (..), WorkOrder (..), WorkOrderStatusCode (..))

parseUTCTime :: Text -> Maybe UTCTime
parseUTCTime t = parseTimeM True defaultTimeLocale "%FT%T%Q%z" (T.unpack t)
           <|> parseTimeM True defaultTimeLocale "%FT%T%QZ" (T.unpack t)

parseDay :: Text -> Maybe Day
parseDay = parseTimeM True defaultTimeLocale "%F" . T.unpack

parseDateAsUTC :: Text -> Maybe UTCTime
parseDateAsUTC t = UTCTime <$> parseDay t <*> pure (secondsToDiffTime 0)

techCardFromRow :: (Single (Maybe Int64), Single Int64, Single Text, Single Text, Single Int64, Single Text, Single Text, Single (Maybe Text)) -> TechCard
techCardFromRow (Single i, Single g, Single n, Single v, Single s, Single ca, Single ua, Single cb) =
    TechCard i g n v (fromIntegral s :: Int) (fromMaybe epoch (parseUTCTime ca)) (fromMaybe epoch (parseUTCTime ua)) cb

workOrderFromRow :: (Single (Maybe Int64), Single Text, Single Int64, Single (Maybe Int64), Single Double, Single Double, Single Int64, Single (Maybe Text), Single (Maybe Text), Single (Maybe Int64), Single (Maybe Text), Single Text, Single Text, Single (Maybe Text)) -> WorkOrder
workOrderFromRow (Single i, Single c, Single g, Single t, Single qp, Single qr, Single s, Single sd, Single ed, Single p, Single n, Single ca, Single ua, Single cb) =
    WorkOrder i c g t qp qr (fromIntegral s :: Int) (sd >>= parseDateAsUTC) (ed >>= parseDateAsUTC) p n (fromMaybe epoch (parseUTCTime ca)) (fromMaybe epoch (parseUTCTime ua)) cb

epoch :: UTCTime
epoch = UTCTime (fromGregorian 1970 1 1) (secondsToDiffTime 0)

listTechCards :: ConnectionPool -> Maybe Int64 -> Maybe Int -> Maybe Int -> IO (QueryResult [TechCard])
listTechCards pool goodsId limitOffset limitCount = do
    let offset = fromMaybe 0 limitOffset
        count = fromMaybe 100 limitCount
    let params = [ case goodsId of { Just g -> PersistInt64 g; Nothing -> PersistNull }
                 , case goodsId of { Just g -> PersistInt64 g; Nothing -> PersistNull }
                 , PersistInt64 (fromIntegral count), PersistInt64 (fromIntegral offset)
                 ]
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT id, goods_id, name, version, status, created_at::TEXT, updated_at::TEXT, created_by FROM tech_card WHERE (? IS NULL OR goods_id = ?) ORDER BY id LIMIT ? OFFSET ?" params)
        pool
    return $ QuerySuccess (map techCardFromRow rows)

createTechCard :: ConnectionPool -> TechCard -> IO (QueryResult TechCard)
createTechCard pool input = do
    let sql = "INSERT INTO tech_card (goods_id, name, version, status, created_at, updated_at, created_by) \
              \VALUES (?, ?, ?, ?, NOW(), NOW(), ?) RETURNING id, goods_id, name, version, status, created_at::TEXT, updated_at::TEXT, created_by"
    let params = [ PersistInt64 (tcGoodsId input), PersistText (tcName input), PersistText (tcVersion input)
                 , PersistInt64 (fromIntegral (tcStatus input)), PersistText (fromMaybe "" (tcCreatedBy input))
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (techCardFromRow row)
        _ -> return $ QueryError "Failed to create tech card"

getTechCard :: ConnectionPool -> Int64 -> IO (QueryResult TechCard)
getTechCard pool tcId = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT id, goods_id, name, version, status, created_at::TEXT, updated_at::TEXT, created_by FROM tech_card WHERE id = ?" [PersistInt64 tcId])
        pool
    case rows of
        (row:_) -> return $ QuerySuccess (techCardFromRow row)
        _ -> return $ QueryError "Not Found"

updateTechCard :: ConnectionPool -> Int64 -> TechCard -> IO (QueryResult TechCard)
updateTechCard pool tcId input = do
    let sql = "UPDATE tech_card SET name = ?, version = ?, status = ?, updated_at = NOW(), created_by = ? WHERE id = ? \
              \RETURNING id, goods_id, name, version, status, created_at::TEXT, updated_at::TEXT, created_by"
    let params = [ PersistText (tcName input), PersistText (tcVersion input)
                 , PersistInt64 (fromIntegral (tcStatus input)), PersistText (fromMaybe "" (tcCreatedBy input))
                 , PersistInt64 tcId
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (techCardFromRow row)
        _ -> return $ QueryError "Not Found"

deleteTechCard :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteTechCard pool tcId = do
    liftIO $ runSqlPool (rawExecute "DELETE FROM tech_card WHERE id = ?" [PersistInt64 tcId]) pool
    return $ QuerySuccess ()

listWorkOrders :: ConnectionPool -> Maybe Int64 -> Maybe Int -> Maybe Int -> IO (QueryResult [WorkOrder])
listWorkOrders pool goodsId limitOffset limitCount = do
    let offset = fromMaybe 0 limitOffset
        count = fromMaybe 100 limitCount
    let params = [ case goodsId of { Just g -> PersistInt64 g; Nothing -> PersistNull }
                 , case goodsId of { Just g -> PersistInt64 g; Nothing -> PersistNull }
                 , PersistInt64 (fromIntegral count), PersistInt64 (fromIntegral offset)
                 ]
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date::TEXT, end_date::TEXT, processor_id, notes, created_at::TEXT, updated_at::TEXT, created_by FROM work_order WHERE (? IS NULL OR goods_id = ?) ORDER BY id LIMIT ? OFFSET ?" params)
        pool
    return $ QuerySuccess (map workOrderFromRow rows)

createWorkOrder :: ConnectionPool -> WorkOrder -> IO (QueryResult WorkOrder)
createWorkOrder pool input = do
    let sql = "INSERT INTO work_order (code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by) \
              \VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW(), ?) \
              \RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date::TEXT, end_date::TEXT, processor_id, notes, created_at::TEXT, updated_at::TEXT, created_by"
    let params = [ PersistText (woCode input), PersistInt64 (woGoodsId input)
                 , case woTechCardId input of { Just t -> PersistInt64 t; Nothing -> PersistNull }
                 , PersistDouble (woQtyPlan input), PersistDouble (woQtyReleased input)
                 , PersistInt64 (fromIntegral (woStatus input))
                  , case woStartDate input of { Just d -> PersistDay (utctDay d); Nothing -> PersistNull }
                  , case woEndDate input of { Just d -> PersistDay (utctDay d); Nothing -> PersistNull }
                  , case woProcessorId input of { Just p -> PersistInt64 p; Nothing -> PersistNull }
                  , case woNotes input of { Just n -> PersistText n; Nothing -> PersistNull }
                  , case woCreatedBy input of { Just c -> PersistText c; Nothing -> PersistNull }
                  ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (workOrderFromRow row)
        _ -> return $ QueryError "Failed to create work order"

getWorkOrder :: ConnectionPool -> Int64 -> IO (QueryResult WorkOrder)
getWorkOrder pool woId = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date::TEXT, end_date::TEXT, processor_id, notes, created_at::TEXT, updated_at::TEXT, created_by FROM work_order WHERE id = ?" [PersistInt64 woId])
        pool
    case rows of
        (row:_) -> return $ QuerySuccess (workOrderFromRow row)
        _ -> return $ QueryError "Not Found"

updateWorkOrder :: ConnectionPool -> Int64 -> WorkOrder -> IO (QueryResult WorkOrder)
updateWorkOrder pool woId input = do
    let sql = "UPDATE work_order SET code = ?, goods_id = ?, tech_card_id = ?, qty_plan = ?, qty_released = ?, status = ?, start_date = ?, end_date = ?, processor_id = ?, notes = ?, updated_at = NOW(), created_by = ? WHERE id = ? \
              \RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date::TEXT, end_date::TEXT, processor_id, notes, created_at::TEXT, updated_at::TEXT, created_by"
    let params = [ PersistText (woCode input), PersistInt64 (woGoodsId input)
                 , case woTechCardId input of { Just t -> PersistInt64 t; Nothing -> PersistNull }
                 , PersistDouble (woQtyPlan input), PersistDouble (woQtyReleased input)
                 , PersistInt64 (fromIntegral (woStatus input))
                 , case woStartDate input of { Just d -> PersistDay (utctDay d); Nothing -> PersistNull }
                 , case woEndDate input of { Just d -> PersistDay (utctDay d); Nothing -> PersistNull }
                 , case woProcessorId input of { Just p -> PersistInt64 p; Nothing -> PersistNull }
                 , case woNotes input of { Just n -> PersistText n; Nothing -> PersistNull }
                 , case woCreatedBy input of { Just c -> PersistText c; Nothing -> PersistNull }
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (workOrderFromRow row)
        _ -> return $ QueryError "Not Found"

deleteWorkOrder :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteWorkOrder pool woId = do
    liftIO $ runSqlPool (rawExecute "DELETE FROM work_order WHERE id = ?" [PersistInt64 woId]) pool
    return $ QuerySuccess ()

releaseWorkOrder :: ConnectionPool -> Int64 -> UTCTime -> Text -> IO (QueryResult WorkOrder)
releaseWorkOrder pool woId releaseTime userId = do
    let sql = "UPDATE work_order SET status = ?, start_at = ?, updated_at = NOW(), updated_by = ? WHERE id = ? \
              \RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date::TEXT, end_date::TEXT, processor_id, notes, created_at::TEXT, updated_at::TEXT, created_by"
    let params = [ PersistInt64 1
                 , PersistUTCTime releaseTime
                 , PersistText userId
                 , PersistInt64 woId
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (workOrderFromRow row)
        _ -> return $ QueryError "Not Found"

completeWorkOrder :: ConnectionPool -> Int64 -> UTCTime -> Text -> IO (QueryResult WorkOrder)
completeWorkOrder pool woId completionTime userId = do
    let sql = "UPDATE work_order SET status = ?, end_at = ?, updated_at = NOW(), updated_by = ? WHERE id = ? \
              \RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date::TEXT, end_date::TEXT, processor_id, notes, created_at::TEXT, updated_at::TEXT, created_by"
    let params = [ PersistInt64 2
                 , PersistUTCTime completionTime
                 , PersistText userId
                 , PersistInt64 woId
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (workOrderFromRow row)
        _ -> return $ QueryError "Not Found"
