{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Mutations (
    createPerson, updatePerson, deletePerson,
    createGoods, updateGoods, deleteGoods,
    createBill, updateBill, updateBillStatus, postBill, postBillWithAcc,
    addBillLine, deleteBillLine, deleteBill,
    createLocation, updateLocation, deleteLocation,
    updateStock, reserveStock, releaseStock,
    createOrder, updateOrderStatus, deleteOrder,
    createPayment, updatePayment, deletePayment,
    createUser, updateUser, listUsers, getUser, deleteUser, authenticateUser,
    createPrice,
    createTax, updateTax, deleteTax,
    createCurrency, updateCurrency, deleteCurrency,
    createAccPlan, updateAccPlan, deleteAccPlan,
    createAccTurn, updateAccTurn, deleteAccTurn,
    createEmployee, updateEmployee, deleteEmployee,
    createSalary, deleteSalary,
    createStockMovement,
    createTimesheet, updateTimesheet, deleteTimesheet
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
import DAL.Conversion (keyToInt)

createPerson :: ConnectionPool -> PersonInput -> IO (QueryResult MutationResult)
createPerson = DAL.MutationsORM.createPerson

updatePerson :: ConnectionPool -> Int64 -> PersonInput -> IO (QueryResult MutationResult)
updatePerson = DAL.MutationsORM.updatePerson

deletePerson :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deletePerson = DAL.MutationsORM.deletePerson

createGoods :: ConnectionPool -> GoodsInput -> IO (QueryResult MutationResult)
createGoods = DAL.MutationsORM.createGoods

updateGoods :: ConnectionPool -> Int64 -> GoodsInput -> IO (QueryResult MutationResult)
updateGoods = DAL.MutationsORM.updateGoods

deleteGoods :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteGoods = DAL.MutationsORM.deleteGoods

createBill :: ConnectionPool -> BillInput -> IO (QueryResult MutationResult)
createBill = DAL.MutationsORM.createBill

updateBill :: ConnectionPool -> Int64 -> BillInput -> IO (QueryResult MutationResult)
updateBill = DAL.MutationsORM.updateBill

updateBillStatus :: ConnectionPool -> Int64 -> Int -> IO (QueryResult MutationResult)
updateBillStatus = DAL.MutationsORM.updateBillStatus

postBill :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
postBill = DAL.MutationsORM.postBill

postBillWithAcc :: ConnectionPool -> Int64 -> IO (QueryResult [Int64])
postBillWithAcc = DAL.MutationsORM.postBillWithAcc

addBillLine :: ConnectionPool -> Int64 -> BillLineInput -> IO (QueryResult MutationResult)
addBillLine = DAL.MutationsORM.addBillLine

deleteBillLine :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteBillLine = DAL.MutationsORM.deleteBillLine

deleteBill :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteBill = DAL.MutationsORM.deleteBill

createLocation :: ConnectionPool -> LocationInput -> IO (QueryResult MutationResult)
createLocation = DAL.MutationsORM.createLocation

updateLocation :: ConnectionPool -> Int64 -> LocationInput -> IO (QueryResult MutationResult)
updateLocation = DAL.MutationsORM.updateLocation

deleteLocation :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteLocation = DAL.MutationsORM.deleteLocation

updateStock :: ConnectionPool -> Int64 -> Int64 -> Double -> IO (QueryResult MutationResult)
updateStock = DAL.MutationsORM.updateStock

reserveStock :: ConnectionPool -> Int64 -> Int64 -> Double -> IO (QueryResult MutationResult)
reserveStock = DAL.MutationsORM.reserveStock

releaseStock :: ConnectionPool -> Int64 -> Int64 -> Double -> IO (QueryResult MutationResult)
releaseStock = DAL.MutationsORM.releaseStock

createOrder :: ConnectionPool -> OrderInput -> IO (QueryResult MutationResult)
createOrder = DAL.MutationsORM.createOrder

updateOrderStatus :: ConnectionPool -> Int64 -> Int -> IO (QueryResult MutationResult)
updateOrderStatus = DAL.MutationsORM.updateOrderStatus

deleteOrder :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteOrder = DAL.MutationsORM.deleteOrder

createPayment :: ConnectionPool -> PaymentInput -> IO (QueryResult MutationResult)
createPayment = DAL.MutationsORM.createPayment

updatePayment :: ConnectionPool -> Int64 -> PaymentInput -> IO (QueryResult MutationResult)
updatePayment = DAL.MutationsORM.updatePayment

deletePayment :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deletePayment = DAL.MutationsORM.deletePayment

createUser :: ConnectionPool -> UserInput -> IO (QueryResult MutationResult)
createUser = DAL.MutationsORM.createUser

updateUser :: ConnectionPool -> Int64 -> UserInput -> IO (QueryResult MutationResult)
updateUser = DAL.MutationsORM.updateUser

listUsers :: ConnectionPool -> IO (QueryResult [User])
listUsers pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            u <- from $ table @UserEntity
            orderBy [asc $ u ^. UserEntityId]
            return u
        ) pool
    return $ QuerySuccess (map userFromEntity entities)

getUser :: ConnectionPool -> Int64 -> IO (QueryResult User)
getUser pool uid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            u <- from $ table @UserEntity
            where_ $ u ^. UserEntityId ==. val (toSqlKey uid)
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
            where_ $ u ^. UserEntityUsername ==. val login
            return u
        ) pool
    case result of
        Nothing -> return $ QuerySuccess Nothing
        Just entity -> do
            let user = userFromEntity entity
            if userPassword user == Just password
                then return $ QuerySuccess (Just user)
                else return $ QuerySuccess Nothing

createAccPlan :: ConnectionPool -> AccPlanInput -> IO (QueryResult MutationResult)
createAccPlan = DAL.MutationsORM.createAccPlan

updateAccPlan :: ConnectionPool -> Int64 -> AccPlanInput -> IO (QueryResult MutationResult)
updateAccPlan = DAL.MutationsORM.updateAccPlan

deleteAccPlan :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteAccPlan = DAL.MutationsORM.deleteAccPlan

createAccTurn :: ConnectionPool -> AccTurnInput -> IO (QueryResult MutationResult)
createAccTurn = DAL.MutationsORM.createAccTurn

updateAccTurn :: ConnectionPool -> Int64 -> AccTurnInput -> IO (QueryResult MutationResult)
updateAccTurn = DAL.MutationsORM.updateAccTurn

deleteAccTurn :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteAccTurn = DAL.MutationsORM.deleteAccTurn

createPrice :: ConnectionPool -> PriceInput -> IO (QueryResult MutationResult)
createPrice = DAL.MutationsORM.createPrice

createTax :: ConnectionPool -> TaxInput -> IO (QueryResult MutationResult)
createTax = DAL.MutationsORM.createTax

updateTax :: ConnectionPool -> Int64 -> TaxInput -> IO (QueryResult MutationResult)
updateTax = DAL.MutationsORM.updateTax

deleteTax :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteTax = DAL.MutationsORM.deleteTax

createCurrency :: ConnectionPool -> CurrencyInput -> IO (QueryResult MutationResult)
createCurrency = DAL.MutationsORM.createCurrency

createEmployee :: ConnectionPool -> EmployeeInput -> IO (QueryResult MutationResult)
createEmployee = DAL.MutationsORM.createEmployee

createSalary :: ConnectionPool -> SalaryInput -> IO (QueryResult MutationResult)
createSalary = DAL.MutationsORM.createSalary

updateEmployee :: ConnectionPool -> Int64 -> EmployeeInput -> IO (QueryResult MutationResult)
updateEmployee = DAL.MutationsORM.updateEmployee

deleteEmployee :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteEmployee = DAL.MutationsORM.deleteEmployee

deleteSalary :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteSalary = DAL.MutationsORM.deleteSalary

createTimesheet :: ConnectionPool -> TimesheetInput -> IO (QueryResult MutationResult)
createTimesheet = DAL.MutationsORM.createTimesheet

updateTimesheet :: ConnectionPool -> Int64 -> TimesheetInput -> IO (QueryResult MutationResult)
updateTimesheet = DAL.MutationsORM.updateTimesheet

deleteTimesheet :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteTimesheet = DAL.MutationsORM.deleteTimesheet

createStockMovement :: ConnectionPool -> StockMovementInput -> IO (QueryResult MutationResult)
createStockMovement = DAL.MutationsORM.createStockMovement

updateCurrency :: ConnectionPool -> Int64 -> CurrencyInput -> IO (QueryResult MutationResult)
updateCurrency = DAL.MutationsORM.updateCurrency

deleteCurrency :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteCurrency = DAL.MutationsORM.deleteCurrency

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
