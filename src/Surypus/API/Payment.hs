{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Payment (
    listPayments,
    createPayment,
    getPayment,
    updatePayment,
    deletePayment,
    getAgingReport,
    PaymentAgingRow (..),
)
where

import Control.Monad.IO.Class (liftIO)
import DAL.Pool (ConnectionPool)
import qualified DAL.Mutations as Mut
import DAL.Types (MutationResult (..), Payment (..), PaymentInput (..), QueryResult (..))
import Data.Aeson (ToJSON, FromJSON)
import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)
import Database.Esqueleto.Experimental
import Database.Persist.Sql (runSqlPool, toSqlKey, rawSql, PersistValue(..), Single(..))
import DAL.Conversion (paymentFromEntity)
import DAL.Schema

data PaymentAgingRow = PaymentAgingRow
  { parBillId :: Int64
  , parBillCode :: Maybe Text
  , parPersonName :: Maybe Text
  , parTotal :: Double
  , parPaid :: Double
  , parBalance :: Double
  , parDaysOverdue :: Int
  , parBucket :: Text
  } deriving (Show, Eq, Generic)
instance ToJSON PaymentAgingRow
instance FromJSON PaymentAgingRow

listPayments :: ConnectionPool -> IO (QueryResult [Payment])
listPayments pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            p <- from $ table @PaymentEntity
            orderBy [desc $ p ^. PaymentEntityDate, desc $ p ^. PaymentEntityId]
            return p
        ) pool
    return $ QuerySuccess (map paymentFromEntity entities)

createPayment :: ConnectionPool -> PaymentInput -> IO (QueryResult MutationResult)
createPayment = Mut.createPayment

getPayment :: ConnectionPool -> Int64 -> IO (QueryResult Payment)
getPayment pool pid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            p <- from $ table @PaymentEntity
            where_ $ p ^. PaymentEntityId ==. val (toSqlKey pid)
            return p
        ) pool
    case result of
        Nothing -> return $ QueryError "Not Found"
        Just entity -> return $ QuerySuccess (paymentFromEntity entity)

updatePayment :: ConnectionPool -> Int64 -> PaymentInput -> IO (QueryResult Payment)
updatePayment pool pid input = do
    result <- Mut.updatePayment pool pid input
    case result of
        QuerySuccess _ -> getPayment pool pid
        QueryError err -> return $ QueryError err

deletePayment :: ConnectionPool -> Int64 -> IO (QueryResult ())
deletePayment pool pid = do
    result <- Mut.deletePayment pool pid
    case result of
        QuerySuccess _ -> return $ QuerySuccess ()
        QueryError err -> return $ QueryError err

getAgingReport :: ConnectionPool -> IO (QueryResult [PaymentAgingRow])
getAgingReport pool = do
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT b.id, b.code, p.name, b.total, \
            \COALESCE(pay.total_paid, 0), \
            \b.total - COALESCE(pay.total_paid, 0), \
            \EXTRACT(DAY FROM NOW() - b.doc_date)::int, \
            \CASE \
            \  WHEN EXTRACT(DAY FROM NOW() - b.doc_date) <= 30 THEN '0-30' \
            \  WHEN EXTRACT(DAY FROM NOW() - b.doc_date) <= 60 THEN '31-60' \
            \  WHEN EXTRACT(DAY FROM NOW() - b.doc_date) <= 90 THEN '61-90' \
            \  ELSE '90+' \
            \END \
            \FROM bill b \
            \LEFT JOIN person p ON b.person_id = p.id \
            \LEFT JOIN (SELECT bill_id, SUM(amount) AS total_paid FROM payment GROUP BY bill_id) pay ON b.id = pay.bill_id \
            \WHERE b.doc_status = 2 \
            \ORDER BY b.doc_date ASC"
            []) pool
    let rows = map (\(Single bid, Single bc, Single pn, Single tot, Single pd, Single bal, Single days, Single bucket) ->
            PaymentAgingRow bid bc pn tot pd bal days bucket) result
    return $ QuerySuccess rows
