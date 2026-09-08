{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DataKinds #-}

module DAL.MutationsORM (
    createPerson,
    updatePerson,
    deletePerson,
    createGoods,
    updateGoods,
    deleteGoods,
    createBill,
    updateBill,
    updateBillStatus,
    postBill,
    postBillWithAcc,
    addBillLine,
    deleteBillLine,
    deleteBill,
    createLocation,
    updateLocation,
    deleteLocation,
    updateStock,
    reserveStock,
    releaseStock,
    createOrder,
    updateOrderStatus,
    deleteOrder,
    createPayment,
    updatePayment,
    deletePayment,
    createUser,
    updateUser,
    createPrice,
    createTax,
    updateTax,
    deleteTax,
    createCurrency,
    updateCurrency,
    deleteCurrency,
    createAccPlan,
    updateAccPlan,
    deleteAccPlan,
    createAccTurn,
    updateAccTurn,
    deleteAccTurn,
    createEmployee,
    updateEmployee,
    deleteEmployee,
    createSalary,
    deleteSalary,
    createStockMovement,
    createTimesheet,
    updateTimesheet,
    deleteTimesheet
) where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime, fromGregorian, getCurrentTime)
import Database.Esqueleto.Experimental
import qualified Database.Persist as P
import Database.Persist.Sql (runSqlPool, toSqlKey)
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Schema
import DAL.Types
import DAL.Conversion

personKey :: Int64 -> P.Key PersonEntity
personKey n = toSqlKey n

goodsKey :: Int64 -> P.Key GoodsEntity
goodsKey n = toSqlKey n

billKey :: Int64 -> P.Key BillEntity
billKey n = toSqlKey n

billLineKey :: Int64 -> P.Key BillLineEntity
billLineKey n = toSqlKey n

locationKey :: Int64 -> P.Key LocationEntity
locationKey n = toSqlKey n

stockToKey :: Int64 -> Int64 -> P.Key StockEntity
stockToKey _ _ = error "stockToKey: composite key not supported, use stockByGoodsLocationId"

runDbMutation :: ConnectionPool -> SqlPersistT IO a -> IO (QueryResult a)
runDbMutation pool stmt = do
    result <- liftIO $ runSqlPool stmt pool
    return $ QuerySuccess result

runMutation :: ConnectionPool -> Text -> IO (QueryResult MutationResult)
runMutation _ msg = return $ QuerySuccess (MutationResult True Nothing msg)

createPerson :: ConnectionPool -> PersonInput -> IO (QueryResult MutationResult)
createPerson pool input = do
    let entity = PersonEntity { personEntityCode = piCode input
        , personEntityName = piName input
        , personEntityInn = piINN input
        , personEntityKpp = piKPP input
        , personEntityPersonType = piPersonType input
        , personEntityStatus = Just (piStatus input)
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Person created successfully")

updatePerson :: ConnectionPool -> Int64 -> PersonInput -> IO (QueryResult MutationResult)
updatePerson pool pid input = do
    _ <- liftIO $ runSqlPool (P.update (personKey pid)
        [ PersonEntityCode P.=. piCode input
        , PersonEntityName P.=. piName input
        , PersonEntityInn P.=. piINN input
        , PersonEntityKpp P.=. piKPP input
        , PersonEntityPersonType P.=. piPersonType input
        , PersonEntityStatus P.=. Just (piStatus input)
        ]) pool
    return $ QuerySuccess (MutationResult True (Just pid) "Person updated successfully")

deletePerson :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deletePerson pool pid = do
    _ <- liftIO $ runSqlPool (P.delete (personKey pid)) pool
    return $ QuerySuccess (MutationResult True (Just pid) "Person deleted successfully")

createGoods :: ConnectionPool -> GoodsInput -> IO (QueryResult MutationResult)
createGoods pool input = do
    let entity = GoodsEntity { goodsEntityCode = giCode input
        , goodsEntityName = giName input
        , goodsEntityBarcode = giBarcode input
        , goodsEntityUnitId = Just (giUnitId input)
        , goodsEntityCategoryId = giParentId input
        , goodsEntityGoodsType = Nothing
        , goodsEntityGoodsStatus = Nothing
        , goodsEntityMinStock = Nothing
        , goodsEntityMaxStock = Nothing
        , goodsEntityWeight = Nothing
        , goodsEntityVolume = Nothing
        , goodsEntityCreatedAt = Nothing
        , goodsEntityUpdatedAt = Nothing
        , goodsEntityFullName = Nothing
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Goods created successfully")

updateGoods :: ConnectionPool -> Int64 -> GoodsInput -> IO (QueryResult MutationResult)
updateGoods pool gid input = do
    _ <- liftIO $ runSqlPool (P.update (goodsKey gid)
        [ GoodsEntityCode P.=. giCode input
        , GoodsEntityName P.=. giName input
        , GoodsEntityBarcode P.=. giBarcode input
        , GoodsEntityUnitId P.=. Just (giUnitId input)
        , GoodsEntityCategoryId P.=. giParentId input
        ]) pool
    return $ QuerySuccess (MutationResult True (Just gid) "Goods updated successfully")

deleteGoods :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteGoods pool gid = do
    _ <- liftIO $ runSqlPool (P.delete (goodsKey gid)) pool
    return $ QuerySuccess (MutationResult True (Just gid) "Goods deleted successfully")

createBill :: ConnectionPool -> BillInput -> IO (QueryResult MutationResult)
createBill pool input = do
    let entity = BillEntity { billEntityCode = biCode input
        , billEntityBillType = biType input
        , billEntityDocStatus = biStatus input
        , billEntityDocDate = biDate input
        , billEntityPersonId = biPersonId input
        , billEntityLocationId = biLocationId input
        , billEntityTotal = biTotal input
        , billEntityDiscountAmount = biDiscount input
        , billEntityTaxAmount = biTax input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Bill created successfully")

updateBill :: ConnectionPool -> Int64 -> BillInput -> IO (QueryResult MutationResult)
updateBill pool bid input = do
    _ <- liftIO $ runSqlPool (P.update (billKey bid)
        [ BillEntityCode P.=. biCode input
        , BillEntityBillType P.=. biType input
        , BillEntityDocStatus P.=. biStatus input
        , BillEntityDocDate P.=. biDate input
        , BillEntityPersonId P.=. biPersonId input
        , BillEntityLocationId P.=. biLocationId input
        , BillEntityTotal P.=. biTotal input
        , BillEntityDiscountAmount P.=. biDiscount input
        , BillEntityTaxAmount P.=. biTax input
        ]) pool
    return $ QuerySuccess (MutationResult True (Just bid) "Bill updated successfully")

updateBillStatus :: ConnectionPool -> Int64 -> Int -> IO (QueryResult MutationResult)
updateBillStatus pool bid status = do
    _ <- liftIO $ runSqlPool (P.update (billKey bid)
        [ BillEntityDocStatus P.=. fromIntegral status
        ]) pool
    return $ QuerySuccess (MutationResult True (Just bid) "Bill status updated")

postBill :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
postBill pool bid = updateBillStatus pool bid 2

postBillWithAcc :: ConnectionPool -> Int64 -> IO (QueryResult [Int64])
postBillWithAcc pool bid = do
    statusResult <- updateBillStatus pool bid 2
    case statusResult of
        QueryError err -> return $ QueryError err
        QuerySuccess _ -> do
            entities <- liftIO $ runSqlPool
                (select $ do
                    bl <- from $ table @BillLineEntity
                    where_ $ bl ^. BillLineEntityBillId ==. val bid
                    return bl)
                pool
            let totalAmount = sum (map (billLineEntityAmount . entityVal) entities)
                placeholderDate = fromGregorian 1970 1 1
                debitEntity = AccTurnEntity
                    { accTurnEntityDocId = Just bid
                    , accTurnEntityDbtAccId = 10
                    , accTurnEntityCrdAccId = 20
                    , accTurnEntityAmount = totalAmount
                    , accTurnEntityDate = placeholderDate
                    }
                creditEntity = AccTurnEntity
                    { accTurnEntityDocId = Just bid
                    , accTurnEntityDbtAccId = 20
                    , accTurnEntityCrdAccId = 10
                    , accTurnEntityAmount = totalAmount
                    , accTurnEntityDate = placeholderDate
                    }
            debitKey <- liftIO $ runSqlPool (P.insert debitEntity) pool
            creditKey <- liftIO $ runSqlPool (P.insert creditEntity) pool
            return $ QuerySuccess [keyToInt debitKey, keyToInt creditKey]

addBillLine :: ConnectionPool -> Int64 -> BillLineInput -> IO (QueryResult MutationResult)
addBillLine pool bid input = do
    let entity = BillLineEntity { billLineEntityBillId = bid
        , billLineEntityGoodsId = bliGoodsId input
        , billLineEntityQtty = bliQtty input
        , billLineEntityPrice = bliPrice input
        , billLineEntityDiscountAmount = bliDiscount input
        , billLineEntityAmount = bliAmount input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Bill line added")

deleteBillLine :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteBillLine pool blid = do
    _ <- liftIO $ runSqlPool (P.delete (billLineKey blid)) pool
    return $ QuerySuccess (MutationResult True (Just blid) "Bill line deleted")

deleteBill :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteBill pool bid = do
    _ <- liftIO $ runSqlPool (P.delete (billKey bid)) pool
    return $ QuerySuccess (MutationResult True (Just bid) "Bill deleted")

createLocation :: ConnectionPool -> LocationInput -> IO (QueryResult MutationResult)
createLocation pool input = do
    let entity = LocationEntity { locationEntityCode = liCode input
        , locationEntityName = liName input
        , locationEntityLocationType = liType input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Location created successfully")

updateLocation :: ConnectionPool -> Int64 -> LocationInput -> IO (QueryResult MutationResult)
updateLocation pool lid input = do
    _ <- liftIO $ runSqlPool (P.update (locationKey lid)
        [ LocationEntityCode P.=. liCode input
        , LocationEntityName P.=. liName input
        , LocationEntityLocationType P.=. liType input
        ]) pool
    return $ QuerySuccess (MutationResult True (Just lid) "Location updated successfully")

deleteLocation :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteLocation pool lid = do
    _ <- liftIO $ runSqlPool (P.delete (locationKey lid)) pool
    return $ QuerySuccess (MutationResult True (Just lid) "Location deleted successfully")

updateStock :: ConnectionPool -> Int64 -> Int64 -> Double -> IO (QueryResult MutationResult)
updateStock pool goodsId locationId qty = do
    _ <- liftIO $ runSqlPool
        (P.updateWhere
            [ StockEntityGoodsId P.==. goodsId
            , StockEntityLocationId P.==. locationId
            ]
            [ StockEntityQtty P.=. qty ]) pool
    return $ QuerySuccess (MutationResult True Nothing "Stock updated")

reserveStock :: ConnectionPool -> Int64 -> Int64 -> Double -> IO (QueryResult MutationResult)
reserveStock pool goodsId locationId qty = do
    current <- liftIO $ runSqlPool
        (P.selectFirst
            [ StockEntityGoodsId P.==. goodsId
            , StockEntityLocationId P.==. locationId
            ] []) pool
    case current of
        Just (P.Entity sid stock) -> do
            _ <- liftIO $ runSqlPool
                (P.update sid [ StockEntityResrvQtty P.=. (stockEntityResrvQtty stock + qty) ]) pool
            return $ QuerySuccess (MutationResult True Nothing "Stock reserved")
        Nothing ->
            return $ QuerySuccess (MutationResult True Nothing "Stock reserved")

releaseStock :: ConnectionPool -> Int64 -> Int64 -> Double -> IO (QueryResult MutationResult)
releaseStock pool goodsId locationId qty = do
    current <- liftIO $ runSqlPool
        (P.selectFirst
            [ StockEntityGoodsId P.==. goodsId
            , StockEntityLocationId P.==. locationId
            , StockEntityResrvQtty P.>=. qty
            ] []) pool
    case current of
        Just (P.Entity sid stock) -> do
            _ <- liftIO $ runSqlPool
                (P.update sid [ StockEntityResrvQtty P.=. (stockEntityResrvQtty stock - qty) ]) pool
            return $ QuerySuccess (MutationResult True Nothing "Stock released")
        Nothing ->
            return $ QuerySuccess (MutationResult True Nothing "Stock released")

createOrder :: ConnectionPool -> OrderInput -> IO (QueryResult MutationResult)
createOrder pool input = do
    let entity = OrderHeadEntity { orderHeadEntityCode = oiCode input
        , orderHeadEntityName = oiName input
        , orderHeadEntityDocDate = oiDate input
        , orderHeadEntityPersonId = oiPersonId input
        , orderHeadEntityLocationId = oiLocationId input
        , orderHeadEntityDocType = oiStatus input
        , orderHeadEntityTotal = oiTotal input
        , orderHeadEntityDiscountAmount = oiDiscount input
        , orderHeadEntityTaxAmount = oiTax input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Order created successfully")

updateOrderStatus :: ConnectionPool -> Int64 -> Int -> IO (QueryResult MutationResult)
updateOrderStatus pool oid status = do
    _ <- liftIO $ runSqlPool (P.update (orderKey oid)
        [ OrderHeadEntityDocType P.=. fromIntegral status
        ]) pool
    return $ QuerySuccess (MutationResult True (Just oid) "Order status updated")

deleteOrder :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteOrder pool oid = do
    _ <- liftIO $ runSqlPool (P.delete (orderKey oid)) pool
    return $ QuerySuccess (MutationResult True (Just oid) "Order deleted")

orderKey :: Int64 -> P.Key OrderHeadEntity
orderKey n = toSqlKey n

createPayment :: ConnectionPool -> PaymentInput -> IO (QueryResult MutationResult)
createPayment pool input = do
    let entity = PaymentEntity { paymentEntityBillId = piBillId input
        , paymentEntityDate = piPayDate input
        , paymentEntityAmount = piAmount input
        , paymentEntityPayMethod = fromIntegral (piPayMethod input)
        , paymentEntityPayStatus = fromIntegral (piPayStatus input)
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Payment created successfully")

updatePayment :: ConnectionPool -> Int64 -> PaymentInput -> IO (QueryResult MutationResult)
updatePayment pool paymentId input = do
    _ <- liftIO $ runSqlPool (P.update (paymentKey paymentId)
        [ PaymentEntityBillId P.=. piBillId input
        , PaymentEntityDate P.=. piPayDate input
        , PaymentEntityAmount P.=. piAmount input
        , PaymentEntityPayMethod P.=. fromIntegral (piPayMethod input)
        , PaymentEntityPayStatus P.=. fromIntegral (piPayStatus input)
        ]) pool
    return $ QuerySuccess (MutationResult True (Just paymentId) "Payment updated successfully")

deletePayment :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deletePayment pool paymentId = do
    _ <- liftIO $ runSqlPool (P.delete (paymentKey paymentId)) pool
    return $ QuerySuccess (MutationResult True (Just paymentId) "Payment deleted")

paymentKey :: Int64 -> P.Key PaymentEntity
paymentKey n = toSqlKey n

createUser :: ConnectionPool -> UserInput -> IO (QueryResult MutationResult)
createUser pool input = do
    let entity = UserEntity { userEntityUsername = uiLogin input
        , userEntityPasswordHash = uiPasswordHash input
        , userEntityEmail = Nothing
        , userEntityPersonId = uiPersonId input
        , userEntityStatus = fromIntegral (uiStatus input)
        , userEntityTenantId = 0
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "User created successfully")

updateUser :: ConnectionPool -> Int64 -> UserInput -> IO (QueryResult MutationResult)
updateUser pool userId input = do
    _ <- liftIO $ runSqlPool (P.update (userKey userId)
        [ UserEntityUsername P.=. uiLogin input
        , UserEntityPasswordHash P.=. uiPasswordHash input
        , UserEntityStatus P.=. fromIntegral (uiStatus input)
        ]) pool
    return $ QuerySuccess (MutationResult True (Just userId) "User updated successfully")

userKey :: Int64 -> P.Key UserEntity
userKey n = toSqlKey n

createPrice :: ConnectionPool -> PriceInput -> IO (QueryResult MutationResult)
createPrice pool input = do
    let entity = GoodsPriceEntity { goodsPriceEntityGoodsId = priGoodsId input
        , goodsPriceEntityPriceType = priPriceType input
        , goodsPriceEntityPrice = priPrice input
        , goodsPriceEntityMinPrice = 0
        , goodsPriceEntityStartDate = Just (priFromDate input)
        , goodsPriceEntityEndDate = priToDate input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Price created")

createTax :: ConnectionPool -> TaxInput -> IO (QueryResult MutationResult)
createTax pool input = do
    let entity = TaxEntity { taxEntityCode = Nothing
        , taxEntityName = tiName input
        , taxEntityRate = tiRate input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Tax created")

updateTax :: ConnectionPool -> Int64 -> TaxInput -> IO (QueryResult MutationResult)
updateTax pool tid input = do
    _ <- liftIO $ runSqlPool (P.update (taxKey tid)
        [ TaxEntityName P.=. tiName input
        , TaxEntityRate P.=. tiRate input
        ]) pool
    return $ QuerySuccess (MutationResult True (Just tid) "Tax updated")

deleteTax :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteTax pool tid = do
    _ <- liftIO $ runSqlPool (P.delete (taxKey tid)) pool
    return $ QuerySuccess (MutationResult True (Just tid) "Tax deleted")

taxKey :: Int64 -> P.Key TaxEntity
taxKey n = toSqlKey n

createCurrency :: ConnectionPool -> CurrencyInput -> IO (QueryResult MutationResult)
createCurrency pool input = do
    let entity = CurrencyEntity { currencyEntityCode = Just (ciCode input)
        , currencyEntitySymbol = Just (ciSymbol input)
        , currencyEntityName = Just (ciName input)
        , currencyEntityRate = ciRate input
        , currencyEntityIsDefault = ciDefault input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Currency created")

updateCurrency :: ConnectionPool -> Int64 -> CurrencyInput -> IO (QueryResult MutationResult)
updateCurrency pool currencyId input = do
    _ <- liftIO $ runSqlPool (P.update (currencyKey currencyId)
        [ CurrencyEntityCode P.=. Just (ciCode input)
        , CurrencyEntitySymbol P.=. Just (ciSymbol input)
        , CurrencyEntityName P.=. Just (ciName input)
        , CurrencyEntityRate P.=. ciRate input
        , CurrencyEntityIsDefault P.=. ciDefault input
        ]) pool
    return $ QuerySuccess (MutationResult True (Just currencyId) "Currency updated")

deleteCurrency :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteCurrency pool cid = do
    _ <- liftIO $ runSqlPool (P.delete (currencyKey cid)) pool
    return $ QuerySuccess (MutationResult True (Just cid) "Currency deleted")

currencyKey :: Int64 -> P.Key CurrencyEntity
currencyKey n = toSqlKey n

createAccPlan :: ConnectionPool -> AccPlanInput -> IO (QueryResult MutationResult)
createAccPlan pool input = do
    let entity = AccPlanEntity { accPlanEntityCode = apiCode input
        , accPlanEntityName = apiName input
        , accPlanEntityAccType = apiType input
        , accPlanEntityParentCode = apiParentCode input
        , accPlanEntityKind = apiKind input
        , accPlanEntityIsAnalytical = apiIsAnalytical input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Account plan created")

updateAccPlan :: ConnectionPool -> Int64 -> AccPlanInput -> IO (QueryResult MutationResult)
updateAccPlan pool planId input = do
    _ <- liftIO $ runSqlPool (P.update (accPlanKey planId)
        [ AccPlanEntityCode P.=. apiCode input
        , AccPlanEntityName P.=. apiName input
        , AccPlanEntityAccType P.=. apiType input
        , AccPlanEntityParentCode P.=. apiParentCode input
        , AccPlanEntityKind P.=. apiKind input
        , AccPlanEntityIsAnalytical P.=. apiIsAnalytical input
        ]) pool
    return $ QuerySuccess (MutationResult True (Just planId) "Account plan updated")

deleteAccPlan :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteAccPlan pool planId = do
    _ <- liftIO $ runSqlPool (P.delete (accPlanKey planId)) pool
    return $ QuerySuccess (MutationResult True (Just planId) "Account plan deleted")

accPlanKey :: Int64 -> P.Key AccPlanEntity
accPlanKey n = toSqlKey n

createAccTurn :: ConnectionPool -> AccTurnInput -> IO (QueryResult MutationResult)
createAccTurn pool input = do
    let entity = AccTurnEntity { accTurnEntityDocId = atiBillId input
        , accTurnEntityDbtAccId = atiDbtAccId input
        , accTurnEntityCrdAccId = atiCrdAccId input
        , accTurnEntityAmount = atiAmount input
        , accTurnEntityDate = atiDate input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Accounting entry created")

updateAccTurn :: ConnectionPool -> Int64 -> AccTurnInput -> IO (QueryResult MutationResult)
updateAccTurn pool turnId input = do
    _ <- liftIO $ runSqlPool (P.update (accTurnKey turnId)
        [ AccTurnEntityDocId P.=. atiBillId input
        , AccTurnEntityDbtAccId P.=. atiDbtAccId input
        , AccTurnEntityCrdAccId P.=. atiCrdAccId input
        , AccTurnEntityAmount P.=. atiAmount input
        , AccTurnEntityDate P.=. atiDate input
        ]) pool
    return $ QuerySuccess (MutationResult True (Just turnId) "Accounting entry updated")

deleteAccTurn :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteAccTurn pool turnId = do
    _ <- liftIO $ runSqlPool (P.delete (accTurnKey turnId)) pool
    return $ QuerySuccess (MutationResult True (Just turnId) "Accounting entry deleted")

accTurnKey :: Int64 -> P.Key AccTurnEntity
accTurnKey n = toSqlKey n

stockMovementKey :: Int64 -> P.Key StockMovementEntity
stockMovementKey n = toSqlKey n

createStockMovement :: ConnectionPool -> StockMovementInput -> IO (QueryResult MutationResult)
createStockMovement pool input = do
    let entity = StockMovementEntity
          { stockMovementEntityGoodsId = smiGoodsId input
          , stockMovementEntityLocationFromId = smiLocationFromId input
          , stockMovementEntityLocationToId = smiLocationToId input
          , stockMovementEntityQtty = smiQtty input
          , stockMovementEntityMovementType = smiMovementType input
          , stockMovementEntityBillId = smiBillId input
          , stockMovementEntityMovementDate = smiMovementDate input
          , stockMovementEntityUserId = Nothing
          , stockMovementEntityNotes = smiNotes input
          , stockMovementEntityCreatedAt = Nothing
          }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Stock movement recorded")

employeeKey :: Int64 -> P.Key EmployeeEntity
employeeKey n = toSqlKey n

salaryKey :: Int64 -> P.Key SalaryEntity
salaryKey n = toSqlKey n

createEmployee :: ConnectionPool -> EmployeeInput -> IO (QueryResult MutationResult)
createEmployee pool input = do
    let entity = EmployeeEntity { employeeEntityCode = eiCode input
        , employeeEntityName = eiName input
        , employeeEntityTabNum = eiTabNum input
        , employeeEntityHireDate = eiHireDate input
        , employeeEntityStatus = eiStatus input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Employee created")

createSalary :: ConnectionPool -> SalaryInput -> IO (QueryResult MutationResult)
createSalary pool input = do
    let net = siGross input - siTax input - siPension input - siOther input
        entity = SalaryEntity { salaryEntityEmployeeId = siEmpId input
        , salaryEntityDate = siDate input
        , salaryEntityGross = siGross input
        , salaryEntityNet = net
        , salaryEntityTaxAmount = siTax input
        , salaryEntityPension = siPension input
        , salaryEntityOther = siOther input
        }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Salary created")

updateEmployee :: ConnectionPool -> Int64 -> EmployeeInput -> IO (QueryResult MutationResult)
updateEmployee pool eid input = do
    liftIO $ runSqlPool (P.update (employeeKey eid)
        [ EmployeeEntityCode P.=. eiCode input
        , EmployeeEntityName P.=. eiName input
        , EmployeeEntityTabNum P.=. eiTabNum input
        , EmployeeEntityHireDate P.=. eiHireDate input
        , EmployeeEntityStatus P.=. eiStatus input
        ]) pool
    return $ QuerySuccess (MutationResult True (Just eid) "Employee updated")

deleteEmployee :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteEmployee pool eid = do
    liftIO $ runSqlPool (P.delete (employeeKey eid)) pool
    return $ QuerySuccess (MutationResult True (Just eid) "Employee deleted")

deleteSalary :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteSalary pool sid = do
    liftIO $ runSqlPool (P.delete (salaryKey sid)) pool
    return $ QuerySuccess (MutationResult True (Just sid) "Salary deleted")

createTimesheet :: ConnectionPool -> TimesheetInput -> IO (QueryResult MutationResult)
createTimesheet pool input = do
    let entity = TimesheetEntity
          { timesheetEntityEmployeeId = tsiEmployeeId input
          , timesheetEntityDate = tsiDate input
          , timesheetEntityHoursWorked = tsiHoursWorked input
          , timesheetEntityNotes = tsiNotes input
          , timesheetEntityCreatedBy = 0
          , timesheetEntityCreatedAt = Nothing
          }
    key <- liftIO $ runSqlPool (P.insert entity) pool
    return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Timesheet created")

updateTimesheet :: ConnectionPool -> Int64 -> TimesheetInput -> IO (QueryResult MutationResult)
updateTimesheet pool tsid input = do
    liftIO $ runSqlPool (P.update (timesheetKey tsid)
        [ TimesheetEntityEmployeeId P.=. tsiEmployeeId input
        , TimesheetEntityDate P.=. tsiDate input
        , TimesheetEntityHoursWorked P.=. tsiHoursWorked input
        , TimesheetEntityNotes P.=. tsiNotes input
        ]) pool
    return $ QuerySuccess (MutationResult True (Just tsid) "Timesheet updated")

deleteTimesheet :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteTimesheet pool tsid = do
    liftIO $ runSqlPool (P.delete (timesheetKey tsid)) pool
    return $ QuerySuccess (MutationResult True (Just tsid) "Timesheet deleted")

timesheetKey :: Int64 -> P.Key TimesheetEntity
timesheetKey n = toSqlKey n
