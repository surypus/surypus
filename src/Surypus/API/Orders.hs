{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.Orders (
    Order (..),
    OrderInput (..),
    OrderLine (..),
    listOrders,
    createOrder,
    getOrder,
    updateOrder,
    deleteOrder,
) where

import Control.Monad.IO.Class (liftIO)
import DAL.Types (QueryResult (..))
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Sql (ConnectionPool, PersistValue (..), rawExecute, rawSql, runSqlPool, Single (..))
import GHC.Generics (Generic)

data Order = Order
    { orderId :: !Text
    , orderType :: !Text
    , orderNumber :: !Text
    , counterpartyId :: !(Maybe Text)
    , orderDate :: !Text
    , totalAmount :: !Double
    , status :: !Text
    , notes :: !(Maybe Text)
    }
    deriving (Show, Eq, Generic)

instance ToJSON Order

data OrderInput = OrderInput
    { oiType :: !Text
    , oiNumber :: !Text
    , oiCounterpartyId :: !(Maybe Text)
    , oiDate :: !Text
    , oiTotalAmount :: !Double
    , oiStatus :: !Text
    , oiNotes :: !(Maybe Text)
    }
    deriving (Show, Eq, Generic)

instance ToJSON OrderInput
instance FromJSON OrderInput

data OrderLine = OrderLine
    { olId :: !Text
    , olOrderId :: !Text
    , olGoodsId :: !(Maybe Text)
    , olQuantity :: !Double
    , olUnitPrice :: !Double
    , olLineTotal :: !Double
    }
    deriving (Show, Eq, Generic)

instance ToJSON OrderLine

parseOrder :: (Single Text, Single Text, Single Text, Single (Maybe Text), Single Text, Single Double, Single Text, Single (Maybe Text)) -> Order
parseOrder (Single i, Single t, Single n, Single c, Single d, Single a, Single s, Single no) =
    Order i t n c d a s no

listOrders :: ConnectionPool -> IO (QueryResult [Order])
listOrders pool = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT id, order_type, order_number, counterparty_id, order_date, total_amount, status, notes FROM orders ORDER BY created_at DESC" []) pool
    return $ QuerySuccess (map parseOrder result)

createOrder :: ConnectionPool -> OrderInput -> IO (QueryResult Order)
createOrder pool input = do
    let sql = "INSERT INTO orders (order_type, order_number, counterparty_id, order_date, total_amount, status, notes) VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id, order_type, order_number, counterparty_id, order_date, total_amount, status, notes"
    let params = [ PersistText (oiType input)
                 , PersistText (oiNumber input)
                 , maybe PersistNull PersistText (oiCounterpartyId input)
                 , PersistText (oiDate input)
                 , PersistDouble (oiTotalAmount input)
                 , PersistText (oiStatus input)
                 , maybe PersistNull PersistText (oiNotes input)
                 ]
    result <- liftIO $ runSqlPool (rawSql sql params) pool
    case result of
        (row:_) -> return $ QuerySuccess (parseOrder row)
        _ -> return $ QueryError "Failed to create order"

getOrder :: ConnectionPool -> Text -> IO (QueryResult Order)
getOrder pool oid = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT id, order_type, order_number, counterparty_id, order_date, total_amount, status, notes FROM orders WHERE id = ?" [PersistText oid]) pool
    case result of
        (row:_) -> return $ QuerySuccess (parseOrder row)
        _ -> return $ QueryError "Not Found"

updateOrder :: ConnectionPool -> Text -> OrderInput -> IO (QueryResult Order)
updateOrder pool oid input = do
    let sql = "UPDATE orders SET order_type = ?, order_number = ?, counterparty_id = ?, order_date = ?, total_amount = ?, status = ?, notes = ? WHERE id = ? RETURNING id, order_type, order_number, counterparty_id, order_date, total_amount, status, notes"
    let params = [ PersistText (oiType input)
                 , PersistText (oiNumber input)
                 , maybe PersistNull PersistText (oiCounterpartyId input)
                 , PersistText (oiDate input)
                 , PersistDouble (oiTotalAmount input)
                 , PersistText (oiStatus input)
                 , maybe PersistNull PersistText (oiNotes input)
                 , PersistText oid
                 ]
    result <- liftIO $ runSqlPool (rawSql sql params) pool
    case result of
        (row:_) -> return $ QuerySuccess (parseOrder row)
        _ -> return $ QueryError "Failed to update order"

deleteOrder :: ConnectionPool -> Text -> IO (QueryResult ())
deleteOrder pool oid = do
    liftIO $ runSqlPool (rawExecute "DELETE FROM orders WHERE id = ?" [PersistText oid]) pool
    return $ QuerySuccess ()
