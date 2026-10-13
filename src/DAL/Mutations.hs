{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}

-- | DAL.Mutations — write operations facade over DAL.MutationsORM.
-- Uniform API: every mutation returns 'QueryResult' 'MutationResult';
-- update/delete functions take the entity id explicitly even though the
-- ORM derives it from the record itself.
module DAL.Mutations
    ( createPerson, updatePerson, deletePerson
    , createGoods, updateGoods, deleteGoods
    , createBill, updateBill, updateBillStatus, postBill, postBillWithAcc
    , addBillLine, deleteBillLine, deleteBill
    , createLocation, updateLocation, deleteLocation
    , updateStock, reserveStock, releaseStock
    , createOrder, updateOrderStatus, deleteOrder
    , createPayment, updatePayment, deletePayment
    , createUser, updateUser, listUsers, getUser, deleteUser, authenticateUser
    , createPrice
    , createTax, updateTax, deleteTax
    , createCurrency, updateCurrency, deleteCurrency
    , createAccPlan, updateAccPlan, deleteAccPlan
    , createAccTurn, updateAccTurn, deleteAccTurn
    , createEmployee, updateEmployee, deleteEmployee
    , createSalary, deleteSalary
    , createStockMovement
    , createTimesheet, updateTimesheet, deleteTimesheet
    ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Control.Monad.IO.Class (liftIO)
import Database.Esqueleto.Experimental
import qualified Database.Persist as P
import Database.Persist.Sql (runSqlPool, toSqlKey)
import Database.Persist.Postgresql (ConnectionPool)
import qualified DAL.MutationsORM
import DAL.Schema
import DAL.Types
import Surypus.DB.Schema (UserEntity(..))
import qualified Surypus.DB.Schema as DBS
import DAL.Conversion (keyToInt)

-- | Wrap a successful ORM key result into a MutationResult.
keyToMutation :: Text -> QueryResult Int64 -> QueryResult MutationResult
keyToMutation msg (QuerySuccess k) = QuerySuccess (MutationResult True (Just k) msg)
keyToMutation _ (QueryError e) = QueryError e
keyToMutation _ (QueryResults _ _) = QueryError "Unexpected result"

-- | Wrap a successful ORM unit result into a MutationResult carrying the id.
unitToMutation :: Int64 -> Text -> QueryResult () -> QueryResult MutationResult
unitToMutation i msg (QuerySuccess ()) = QuerySuccess (MutationResult True (Just i) msg)
unitToMutation _ _ (QueryError e) = QueryError e
unitToMutation _ _ (QueryResults _ _) = QueryError "Unexpected result"

-- Persons ---------------------------------------------------------------------

createPerson :: ConnectionPool -> Person -> IO (QueryResult MutationResult)
createPerson pool person =
  keyToMutation "Person created" <$> DAL.MutationsORM.createPerson pool person

updatePerson :: ConnectionPool -> Int64 -> Person -> IO (QueryResult MutationResult)
updatePerson pool pid person =
  unitToMutation pid "Person updated" <$> DAL.MutationsORM.updatePerson pool person

deletePerson :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deletePerson pool pid =
  unitToMutation pid "Person deleted" <$> DAL.MutationsORM.deletePerson pool pid

-- Goods -----------------------------------------------------------------------

createGoods :: ConnectionPool -> Goods -> IO (QueryResult MutationResult)
createGoods pool goods =
  keyToMutation "Goods created" <$> DAL.MutationsORM.createGoods pool goods

updateGoods :: ConnectionPool -> Int64 -> Goods -> IO (QueryResult MutationResult)
updateGoods pool gid goods =
  unitToMutation gid "Goods updated" <$> DAL.MutationsORM.updateGoods pool goods

deleteGoods :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteGoods pool gid =
  unitToMutation gid "Goods deleted" <$> DAL.MutationsORM.deleteGoods pool gid

-- Bills -----------------------------------------------------------------------

createBill :: ConnectionPool -> Bill -> IO (QueryResult MutationResult)
createBill pool bill =
  keyToMutation "Bill created" <$> DAL.MutationsORM.createBill pool bill

updateBill :: ConnectionPool -> Int64 -> Bill -> IO (QueryResult MutationResult)
updateBill pool bid bill =
  unitToMutation bid "Bill updated" <$> DAL.MutationsORM.updateBill pool bill

updateBillStatus :: ConnectionPool -> Int64 -> Text -> IO (QueryResult MutationResult)
updateBillStatus pool bid status =
  unitToMutation bid "Bill status updated" <$> DAL.MutationsORM.updateBillStatus pool bid status

postBill :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
postBill pool bid =
  unitToMutation bid "Bill posted" <$> DAL.MutationsORM.postBill pool bid

postBillWithAcc :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
postBillWithAcc pool bid =
  unitToMutation bid "Bill posted with accounting" <$> DAL.MutationsORM.postBillWithAcc pool bid

addBillLine :: ConnectionPool -> BillLine -> IO (QueryResult MutationResult)
addBillLine pool line =
  keyToMutation "Bill line added" <$> DAL.MutationsORM.addBillLine pool line

deleteBillLine :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteBillLine pool lid =
  unitToMutation lid "Bill line deleted" <$> DAL.MutationsORM.deleteBillLine pool lid

deleteBill :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteBill pool bid =
  unitToMutation bid "Bill deleted" <$> DAL.MutationsORM.deleteBill pool bid

-- Locations -------------------------------------------------------------------

createLocation :: ConnectionPool -> Location -> IO (QueryResult MutationResult)
createLocation pool loc =
  keyToMutation "Location created" <$> DAL.MutationsORM.createLocation pool loc

updateLocation :: ConnectionPool -> Int64 -> Location -> IO (QueryResult MutationResult)
updateLocation pool lid loc =
  unitToMutation lid "Location updated" <$> DAL.MutationsORM.updateLocation pool loc

deleteLocation :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteLocation pool lid =
  unitToMutation lid "Location deleted" <$> DAL.MutationsORM.deleteLocation pool lid

-- Stock -----------------------------------------------------------------------

updateStock :: ConnectionPool -> Int64 -> Double -> IO (QueryResult MutationResult)
updateStock pool goodsId qty =
  unitToMutation goodsId "Stock updated" <$> DAL.MutationsORM.updateStock pool goodsId qty

reserveStock :: ConnectionPool -> Int64 -> Double -> IO (QueryResult MutationResult)
reserveStock pool goodsId qty =
  unitToMutation goodsId "Stock reserved" <$> DAL.MutationsORM.reserveStock pool goodsId qty

releaseStock :: ConnectionPool -> Int64 -> Double -> IO (QueryResult MutationResult)
releaseStock pool goodsId qty =
  unitToMutation goodsId "Stock released" <$> DAL.MutationsORM.releaseStock pool goodsId qty

-- Orders ----------------------------------------------------------------------

createOrder :: ConnectionPool -> Order -> IO (QueryResult MutationResult)
createOrder pool order =
  keyToMutation "Order created" <$> DAL.MutationsORM.createOrder pool order

updateOrderStatus :: ConnectionPool -> Int64 -> Text -> IO (QueryResult MutationResult)
updateOrderStatus pool oid status =
  unitToMutation oid "Order status updated" <$> DAL.MutationsORM.updateOrderStatus pool oid status

deleteOrder :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteOrder pool oid =
  unitToMutation oid "Order deleted" <$> DAL.MutationsORM.deleteOrder pool oid

-- Payments --------------------------------------------------------------------

createPayment :: ConnectionPool -> Payment -> IO (QueryResult MutationResult)
createPayment pool payment =
  keyToMutation "Payment created" <$> DAL.MutationsORM.createPayment pool payment

updatePayment :: ConnectionPool -> Int64 -> Payment -> IO (QueryResult MutationResult)
updatePayment pool pid payment =
  unitToMutation pid "Payment updated" <$> DAL.MutationsORM.updatePayment pool payment

deletePayment :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deletePayment pool pid =
  unitToMutation pid "Payment deleted" <$> DAL.MutationsORM.deletePayment pool pid

-- Users -----------------------------------------------------------------------

createUser :: ConnectionPool -> UserInput -> IO (QueryResult MutationResult)
createUser pool input = do
  let user = User
        { userId = 0
        , userName = uiUsername input
        , userPassword = Just (uiPasswordHash input)
        , userEmail = uiEmail input
        , userPersonId = Nothing
        , userStatus = uiStatus input
        , userTenantId = 0
        }
  keyToMutation "User created" <$> DAL.MutationsORM.createUser pool user

updateUser :: ConnectionPool -> Int64 -> UserInput -> IO (QueryResult MutationResult)
updateUser pool uid input = do
  existing <- getUser pool uid
  case existing of
    QueryError e -> return $ QueryError e
    QuerySuccess old -> do
      let user = old
            { userName = uiUsername input
            , userPassword = Just (uiPasswordHash input)
            , userEmail = uiEmail input
            , userStatus = uiStatus input
            }
      unitToMutation uid "User updated" <$> DAL.MutationsORM.updateUser pool user
    QueryResults _ _ -> return $ QueryError "Unexpected result"

listUsers :: ConnectionPool -> IO (QueryResult [User])
listUsers pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            u <- from $ table @UserEntity
            orderBy [asc $ u ^. DBS.UserEntityId]
            return u
        ) pool
    return $ QuerySuccess (map userFromEntity entities)

getUser :: ConnectionPool -> Int64 -> IO (QueryResult User)
getUser pool uid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            u <- from $ table @UserEntity
            where_ $ u ^. DBS.UserEntityId ==. val (toSqlKey uid)
            return u
        ) pool
    case result of
        Nothing -> return $ QueryError "User not found"
        Just entity -> return $ QuerySuccess (userFromEntity entity)

deleteUser :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteUser pool uid = do
    liftIO $ runSqlPool (P.delete (toSqlKey uid :: P.Key UserEntity)) pool
    return $ QuerySuccess $ MutationResult True (Just uid) "User deleted"

authenticateUser :: ConnectionPool -> Text -> Text -> IO (QueryResult (Maybe User))
authenticateUser pool login password = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            u <- from $ table @UserEntity
            where_ $ u ^. DBS.UserEntityUsername ==. val login
            return u
        ) pool
    case result of
        Nothing -> return $ QuerySuccess Nothing
        Just entity -> do
            let user = userFromEntity entity
            if userPassword user == Just password
                then return $ QuerySuccess (Just user)
                else return $ QuerySuccess Nothing

userFromEntity :: P.Entity UserEntity -> User
userFromEntity (P.Entity key e) = User
    { userId = keyToInt key
    , userName = userEntityUsername e
    , userPassword = Just $ userEntityPasswordHash e
    , userEmail = Nothing
    , userPersonId = userEntityPersonId e
    , userStatus = userEntityStatus e
    , userTenantId = userEntityTenantId e
    }

-- Prices ----------------------------------------------------------------------

createPrice :: ConnectionPool -> GoodsPrice -> IO (QueryResult MutationResult)
createPrice pool price =
  keyToMutation "Price created" <$> DAL.MutationsORM.createPrice pool price

-- Taxes -----------------------------------------------------------------------

createTax :: ConnectionPool -> Tax -> IO (QueryResult MutationResult)
createTax pool tax =
  keyToMutation "Tax created" <$> DAL.MutationsORM.createTax pool tax

updateTax :: ConnectionPool -> Int64 -> Tax -> IO (QueryResult MutationResult)
updateTax pool tid tax =
  unitToMutation tid "Tax updated" <$> DAL.MutationsORM.updateTax pool tax

deleteTax :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteTax pool tid =
  unitToMutation tid "Tax deleted" <$> DAL.MutationsORM.deleteTax pool tid

-- Currencies ------------------------------------------------------------------

createCurrency :: ConnectionPool -> Currency -> IO (QueryResult MutationResult)
createCurrency pool currency =
  keyToMutation "Currency created" <$> DAL.MutationsORM.createCurrency pool currency

updateCurrency :: ConnectionPool -> Int64 -> Currency -> IO (QueryResult MutationResult)
updateCurrency pool cid currency =
  unitToMutation cid "Currency updated" <$> DAL.MutationsORM.updateCurrency pool currency

deleteCurrency :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteCurrency pool cid =
  unitToMutation cid "Currency deleted" <$> DAL.MutationsORM.deleteCurrency pool cid

-- Account plans ---------------------------------------------------------------

createAccPlan :: ConnectionPool -> AccPlan -> IO (QueryResult MutationResult)
createAccPlan pool acc =
  keyToMutation "Account plan created" <$> DAL.MutationsORM.createAccPlan pool acc

updateAccPlan :: ConnectionPool -> Int64 -> AccPlan -> IO (QueryResult MutationResult)
updateAccPlan pool pid acc =
  unitToMutation pid "Account plan updated" <$> DAL.MutationsORM.updateAccPlan pool acc

deleteAccPlan :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteAccPlan pool pid =
  unitToMutation pid "Account plan deleted" <$> DAL.MutationsORM.deleteAccPlan pool pid

-- Account turns ---------------------------------------------------------------

createAccTurn :: ConnectionPool -> AccTurnInput -> IO (QueryResult MutationResult)
createAccTurn pool input = do
  let turn = AccTurn
        { accTurnId = 0
        , accTurnDebitAccount = T.pack (show (atiDbtAccId input))
        , accTurnCreditAccount = T.pack (show (atiCrdAccId input))
        , accTurnAmount = atiAmount input
        , accTurnDescription = atiDescription input
        }
  result <- DAL.MutationsORM.createAccTurn pool turn
  return $ case result of
    QuerySuccess _ -> QuerySuccess (MutationResult True Nothing "AccTurn created")
    QueryError e   -> QueryError e
    QueryResults _ _ -> QueryError "Unexpected result"

updateAccTurn :: ConnectionPool -> Int64 -> AccTurnInput -> IO (QueryResult MutationResult)
updateAccTurn pool tid input = do
  let turn = AccTurn
        { accTurnId = tid
        , accTurnDebitAccount = T.pack (show (atiDbtAccId input))
        , accTurnCreditAccount = T.pack (show (atiCrdAccId input))
        , accTurnAmount = atiAmount input
        , accTurnDescription = atiDescription input
        }
  result <- DAL.MutationsORM.updateAccTurn pool turn
  return $ case result of
    QuerySuccess _ -> QuerySuccess (MutationResult True (Just tid) "AccTurn updated")
    QueryError e   -> QueryError e
    QueryResults _ _ -> QueryError "Unexpected result"

deleteAccTurn :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteAccTurn pool tid =
  unitToMutation tid "AccTurn deleted" <$> DAL.MutationsORM.deleteAccTurn pool tid

-- Employees -------------------------------------------------------------------

createEmployee :: ConnectionPool -> Employee -> IO (QueryResult MutationResult)
createEmployee pool emp =
  keyToMutation "Employee created" <$> DAL.MutationsORM.createEmployee pool emp

updateEmployee :: ConnectionPool -> Int64 -> Employee -> IO (QueryResult MutationResult)
updateEmployee pool eid emp =
  unitToMutation eid "Employee updated" <$> DAL.MutationsORM.updateEmployee pool emp

deleteEmployee :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteEmployee pool eid =
  unitToMutation eid "Employee deleted" <$> DAL.MutationsORM.deleteEmployee pool eid

-- Salaries --------------------------------------------------------------------

createSalary :: ConnectionPool -> Salary -> IO (QueryResult MutationResult)
createSalary pool salary =
  keyToMutation "Salary created" <$> DAL.MutationsORM.createSalary pool salary

deleteSalary :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteSalary pool sid =
  unitToMutation sid "Salary deleted" <$> DAL.MutationsORM.deleteSalary pool sid

-- Stock movements -------------------------------------------------------------

createStockMovement :: ConnectionPool -> StockMovement -> IO (QueryResult MutationResult)
createStockMovement pool movement =
  keyToMutation "Stock movement created" <$> DAL.MutationsORM.createStockMovement pool movement

-- Timesheets ------------------------------------------------------------------

createTimesheet :: ConnectionPool -> Timesheet -> IO (QueryResult MutationResult)
createTimesheet pool ts =
  keyToMutation "Timesheet created" <$> DAL.MutationsORM.createTimesheet pool ts

updateTimesheet :: ConnectionPool -> Int64 -> Timesheet -> IO (QueryResult MutationResult)
updateTimesheet pool tid ts =
  unitToMutation tid "Timesheet updated" <$> DAL.MutationsORM.updateTimesheet pool ts

deleteTimesheet :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteTimesheet pool tid =
  unitToMutation tid "Timesheet deleted" <$> DAL.MutationsORM.deleteTimesheet pool tid
