{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DataKinds #-}

module DAL.QueriesORM where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Text (Text)
import Database.Esqueleto.Experimental
import qualified Database.Esqueleto as E
import qualified Database.Persist as P
import Database.Persist.Sql (runSqlPool, toSqlKey)
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Schema
import DAL.Types
import DAL.Conversion

-- | Key helpers
personKey :: Int64 -> P.Key PersonEntity
personKey n = toSqlKey n

goodsKey :: Int64 -> P.Key GoodsEntity
goodsKey n = toSqlKey n

billKey :: Int64 -> P.Key BillEntity
billKey n = toSqlKey n

locationKey :: Int64 -> P.Key LocationEntity
locationKey n = toSqlKey n

lotKey :: Int64 -> P.Key LotEntity
lotKey n = toSqlKey n

tenantKey :: Int64 -> P.Key TenantEntity
tenantKey n = toSqlKey n

taxKey :: Int64 -> P.Key TaxEntity
taxKey n = toSqlKey n

currencyKey :: Int64 -> P.Key CurrencyEntity
currencyKey n = toSqlKey n

-- | Additional conversion functions needed
billLineFromEntity :: P.Entity BillLineEntity -> BillLine
billLineFromEntity (P.Entity lid e) = BillLine
  { lineId = keyToInt lid
  , lineBillId = billLineEntityBillId e
  , lineGoodId = billLineEntityGoodsId e
  , lineQtty = billLineEntityQtty e
  , linePrice = billLineEntityPrice e
  , lineDiscount = billLineEntityDiscountAmount e
  , lineAmount = billLineEntityAmount e
  }

employeeToDummyUser :: EmployeeEntity -> User
employeeToDummyUser e = User
  { userId = 0
  , userName = employeeEntityName e
  , userPassword = Just (employeeEntityCode e)
  , userEmail = Nothing
  , userPersonId = Nothing
  , userStatus = employeeEntityStatus e
  , userTenantId = 0
  }

documentTypeFromEntity :: P.Entity DocumentTypeEntity -> DocumentRegisterType
documentTypeFromEntity (P.Entity tid e) = DocumentRegisterType
  { drtId = keyToInt tid
  , drtCode = documentTypeEntityCode e
  , drtName = documentTypeEntityName e
  , drtDescription = documentTypeEntityDescription e
  }

orderFromEntity :: P.Entity OrderHeadEntity -> Order
orderFromEntity (P.Entity oid e) = Order
  { orderId = keyToInt oid
  , orderCode = orderHeadEntityCode e
  , orderName = orderHeadEntityName e
  , orderDate = orderHeadEntityDocDate e
  , orderPersonId = orderHeadEntityPersonId e
  , orderLocationId = orderHeadEntityLocationId e
  , orderType = orderHeadEntityDocType e
  , orderTotal = orderHeadEntityTotal e
  , orderDiscount = orderHeadEntityDiscountAmount e
  , orderTax = orderHeadEntityTaxAmount e
  }

goodsPriceFromEntity :: P.Entity GoodsPriceEntity -> GoodsPrice
goodsPriceFromEntity (P.Entity gid e) = GoodsPrice
  { goodsPriceId = keyToInt gid
  , goodsPriceGoodsId = goodsPriceEntityGoodsId e
  , goodsPriceType = goodsPriceEntityPriceType e
  , goodsPricePrice = goodsPriceEntityPrice e
  , goodsPriceMinPrice = goodsPriceEntityMinPrice e
  , goodsPriceStartDate = goodsPriceEntityStartDate e
  , goodsPriceEndDate = goodsPriceEntityEndDate e
  }

reportTemplateFromEntity :: P.Entity ReportTemplateEntity -> ReportTemplate
reportTemplateFromEntity (P.Entity rid e) = ReportTemplate
  { reportTemplateId = keyToInt rid
  , reportTemplateCode = reportTemplateEntityCode e
  , reportTemplateName = reportTemplateEntityName e
  , reportTemplateType = reportTemplateEntityReportType e
  , reportTemplateContent = reportTemplateEntityContent e
  , reportTemplateFormat = reportTemplateEntityFormat e
  }

currencyFromEntity :: P.Entity CurrencyEntity -> Currency
currencyFromEntity (P.Entity cid e) = Currency
  { currencyId = keyToInt cid
  , currencyCode = currencyEntityCode e
  , currencySymbol = currencyEntitySymbol e
  , currencyName = currencyEntityName e
  , currencyRate = currencyEntityRate e
  , currencyDefault = currencyEntityIsDefault e
  }

-- | Get all persons
getPersons :: ConnectionPool -> IO (QueryResult [Person])
getPersons pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      p <- from $ table @PersonEntity
      return p)
    pool
  return $ QuerySuccess $ map personFromEntity entities

-- | Search persons by name/code/INN
searchPersons :: ConnectionPool -> Text -> IO (QueryResult [Person])
searchPersons pool query = do
  entities <- liftIO $ runSqlPool
    (select $ do
      p <- from $ table @PersonEntity
      let valPattern = "%" <> query <> "%"
      where_ $ (p ^. PersonEntityName `ilike` val valPattern
               ) ||. (p ^. PersonEntityInn `ilike` val (Just valPattern)
               ) ||. (p ^. PersonEntityCode `ilike` val (Just valPattern))
      orderBy [asc $ p ^. personEntityId]
      return p)
    pool
  return $ QuerySuccess $ map personFromEntity entities

-- | Get person by ID
getPersonById :: ConnectionPool -> Int64 -> IO (QueryResult Person)
getPersonById pool pid = do
  result <- liftIO $ runSqlPool
    (selectOne $ do
      p <- from $ table @PersonEntity
      where_ $ p ^. personEntityId ==. val (personKey pid)
      return p)
    pool
  return $ case result of
    Just entity -> QuerySuccess $ personFromEntity entity
    Nothing -> QueryError "Not Found"

-- | Get all goods
getGoods :: ConnectionPool -> IO (QueryResult [Goods])
getGoods pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      g <- from $ table @GoodsEntity
      orderBy [asc $ g ^. GoodsEntityId]
      return g)
    pool
  return $ QuerySuccess $ map goodsFromEntity entities

-- | Search goods by name/code/barcode
searchGoods :: ConnectionPool -> Text -> IO (QueryResult [Goods])
searchGoods pool query = do
  entities <- liftIO $ runSqlPool
    (select $ do
      g <- from $ table @GoodsEntity
      let valPattern = "%" <> query <> "%"
      where_ $ (g ^. GoodsEntityName `ilike` val valPattern
               ) ||. (g ^. GoodsEntityCode `ilike` val (Just valPattern)
               ) ||. (g ^. GoodsEntityBarcode `ilike` val (Just valPattern))
      orderBy [asc $ g ^. GoodsEntityId]
      return g)
    pool
  return $ QuerySuccess $ map goodsFromEntity entities

-- | Get goods by ID
getGoodsById :: ConnectionPool -> Int64 -> IO (QueryResult Goods)
getGoodsById pool gid = do
  result <- liftIO $ runSqlPool
    (selectOne $ do
      g <- from $ table @GoodsEntity
      where_ $ g ^. GoodsEntityId ==. val (goodsKey gid)
      return g)
    pool
  return $ case result of
    Just entity -> QuerySuccess $ goodsFromEntity entity
    Nothing -> QueryError "Not Found"

-- | Get goods by barcode
getGoodsByBarcode :: ConnectionPool -> Text -> IO (QueryResult Goods)
getGoodsByBarcode pool barcode = do
  result <- liftIO $ runSqlPool
    (selectOne $ do
      g <- from $ table @GoodsEntity
      where_ $ g ^. GoodsEntityBarcode ==. val (Just barcode)
      return g)
    pool
  return $ case result of
    Just entity -> QuerySuccess $ goodsFromEntity entity
    Nothing -> QueryError "Not Found"

-- | Get all locations
getLocations :: ConnectionPool -> IO (QueryResult [Location])
getLocations pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      l <- from $ table @LocationEntity
      orderBy [asc $ l ^. LocationEntityId]
      return l)
    pool
  return $ QuerySuccess $ map locationFromEntity entities

-- | Get location by ID
getLocationById :: ConnectionPool -> Int64 -> IO (QueryResult Location)
getLocationById pool lid = do
  result <- liftIO $ runSqlPool
    (selectOne $ do
      l <- from $ table @LocationEntity
      where_ $ l ^. LocationEntityId ==. val (locationKey lid)
      return l)
    pool
  return $ case result of
    Just entity -> QuerySuccess $ locationFromEntity entity
    Nothing -> QueryError "Not Found"

-- | Get all bills
getBills :: ConnectionPool -> IO (QueryResult [Bill])
getBills pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      b <- from $ table @BillEntity
      orderBy [asc $ b ^. BillEntityId]
      return b)
    pool
  return $ QuerySuccess $ map billFromEntity entities

-- | Get bill by ID
getBillById :: ConnectionPool -> Int64 -> IO (QueryResult Bill)
getBillById pool bid = do
  result <- liftIO $ runSqlPool
    (selectOne $ do
      b <- from $ table @BillEntity
      where_ $ b ^. BillEntityId ==. val (billKey bid)
      return b)
    pool
  return $ case result of
    Just entity -> QuerySuccess $ billFromEntity entity
    Nothing -> QueryError "Not Found"

-- | Get bill lines
getBillLines :: ConnectionPool -> Int64 -> IO (QueryResult [BillLine])
getBillLines pool bid = do
  entities <- liftIO $ runSqlPool
    (select $ do
      bl <- from $ table @BillLineEntity
      where_ $ bl ^. BillLineEntityBillId ==. val bid
      orderBy [asc $ bl ^. BillLineEntityId]
      return bl)
    pool
  return $ QuerySuccess $ map billLineFromEntity entities

-- | Get all stock
getStockAll :: ConnectionPool -> IO (QueryResult [Stock])
getStockAll pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      s <- from $ table @StockEntity
      orderBy [asc $ s ^. StockEntityId]
      return s)
    pool
  return $ QuerySuccess $ map stockFromEntity entities

-- | Get stock by location
getStockByLocation :: ConnectionPool -> Int64 -> IO (QueryResult [Stock])
getStockByLocation pool lid = do
  entities <- liftIO $ runSqlPool
    (select $ do
      s <- from $ table @StockEntity
      where_ $ s ^. StockEntityLocationId ==. val lid
      return s)
    pool
  return $ QuerySuccess $ map stockFromEntity entities

-- | Get stock by goods
getStockByGoods :: ConnectionPool -> Int64 -> IO (QueryResult [Stock])
getStockByGoods pool gid = do
  entities <- liftIO $ runSqlPool
    (select $ do
      s <- from $ table @StockEntity
      where_ $ s ^. StockEntityGoodsId ==. val gid
      return s)
    pool
  return $ QuerySuccess $ map stockFromEntity entities

-- | Get all lots
getLots :: ConnectionPool -> IO (QueryResult [Lot])
getLots pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      l <- from $ table @LotEntity
      orderBy [desc $ l ^. LotEntityDt, desc $ l ^. LotEntityId]
      return l)
    pool
  return $ QuerySuccess $ map lotFromEntity entities

-- | Get lots by goods
getLotsByGoods :: ConnectionPool -> Int64 -> IO (QueryResult [Lot])
getLotsByGoods pool gid = do
  entities <- liftIO $ runSqlPool
    (select $ do
      l <- from $ table @LotEntity
      where_ $ l ^. LotEntityGoodsId ==. val gid
      orderBy [desc $ l ^. LotEntityDt, desc $ l ^. LotEntityId]
      return l)
    pool
  return $ QuerySuccess $ map lotFromEntity entities

-- | Get lots by location
getLotsByLocation :: ConnectionPool -> Int64 -> IO (QueryResult [Lot])
getLotsByLocation pool lid = do
  entities <- liftIO $ runSqlPool
    (select $ do
      l <- from $ table @LotEntity
      where_ $ l ^. LotEntityLocationId ==. val lid
      orderBy [desc $ l ^. LotEntityDt, desc $ l ^. LotEntityId]
      return l)
    pool
  return $ QuerySuccess $ map lotFromEntity entities

-- | Get lot by ID
getLotById :: ConnectionPool -> Int64 -> IO (QueryResult Lot)
getLotById pool lid = do
  result <- liftIO $ runSqlPool
    (selectOne $ do
      l <- from $ table @LotEntity
      where_ $ l ^. LotEntityId ==. val (lotKey lid)
      return l)
    pool
  return $ case result of
    Just entity -> QuerySuccess $ lotFromEntity entity
    Nothing -> QueryError "Not Found"

-- | Get users (employees with roles - simplified)
getUsers :: ConnectionPool -> IO (QueryResult [User])
getUsers pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      e <- from $ table @EmployeeEntity
      orderBy [asc $ e ^. EmployeeEntityId]
      return e)
    pool
  return $ QuerySuccess $ map (employeeToDummyUser . entityVal) entities

-- | Get employees
getEmployees :: ConnectionPool -> IO (QueryResult [Employee])
getEmployees pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      e <- from $ table @EmployeeEntity
      orderBy [asc $ e ^. EmployeeEntityId]
      return e)
    pool
  return $ QuerySuccess $ map employeeFromEntity entities

-- | Get salaries
getSalaries :: ConnectionPool -> IO (QueryResult [Salary])
getSalaries pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      s <- from $ table @SalaryEntity
      orderBy [desc $ s ^. SalaryEntityDate, desc $ s ^. SalaryEntityId]
      return s)
    pool
  return $ QuerySuccess $ map salaryFromEntity entities

-- | Get accounting plans
getAccPlans :: ConnectionPool -> IO (QueryResult [AccPlan])
getAccPlans pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      a <- from $ table @AccPlanEntity
      orderBy [asc $ a ^. AccPlanEntityCode]
      return a)
    pool
  return $ QuerySuccess $ map accPlanFromEntity entities

-- | Get accounting turns
getAccTurns :: ConnectionPool -> IO (QueryResult [AccTurn])
getAccTurns pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      a <- from $ table @AccTurnEntity
      orderBy [desc $ a ^. AccTurnEntityDate, desc $ a ^. AccTurnEntityId]
      return a)
    pool
  return $ QuerySuccess $ map accTurnFromEntity entities

-- | Get payments
getPayments :: ConnectionPool -> IO (QueryResult [Payment])
getPayments pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      p <- from $ table @PaymentEntity
      orderBy [desc $ p ^. PaymentEntityDate, desc $ p ^. PaymentEntityId]
      return p)
    pool
  return $ QuerySuccess $ map paymentFromEntity entities

-- | Get units
getUnits :: ConnectionPool -> IO (QueryResult [Unit])
getUnits pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      u <- from $ table @UnitEntity
      orderBy [asc $ u ^. UnitEntityId]
      return u)
    pool
  return $ QuerySuccess $ map unitFromEntity entities

-- | Get taxes
getTaxes :: ConnectionPool -> IO (QueryResult [Tax])
getTaxes pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      t <- from $ table @TaxEntity
      orderBy [asc $ t ^. TaxEntityId]
      return t)
    pool
  return $ QuerySuccess $ map taxFromEntity entities

-- | Get document types
getDocumentTypes :: ConnectionPool -> IO (QueryResult [DocumentRegisterType])
getDocumentTypes pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      dt <- from $ table @DocumentTypeEntity
      orderBy [asc $ dt ^. DocumentTypeEntityId]
      return dt)
    pool
  return $ QuerySuccess $ map documentTypeFromEntity entities

-- | Get orders
getOrders :: ConnectionPool -> IO (QueryResult [Order])
getOrders pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      o <- from $ table @OrderHeadEntity
      orderBy [desc $ o ^. OrderHeadEntityDocDate, desc $ o ^. OrderHeadEntityId]
      return o)
    pool
  return $ QuerySuccess $ map orderFromEntity entities

-- | Get goods prices
getGoodsPrices :: ConnectionPool -> IO (QueryResult [GoodsPrice])
getGoodsPrices pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      gp <- from $ table @GoodsPriceEntity
      orderBy [asc $ gp ^. GoodsPriceEntityId]
      return gp)
    pool
  return $ QuerySuccess $ map goodsPriceFromEntity entities

-- | Get report templates
getReports :: ConnectionPool -> IO (QueryResult [ReportTemplate])
getReports pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      r <- from $ table @ReportTemplateEntity
      orderBy [asc $ r ^. ReportTemplateEntityId]
      return r)
    pool
  return $ QuerySuccess $ map reportTemplateFromEntity entities

-- | Get all tenants
getTenants :: ConnectionPool -> IO (QueryResult [Tenant])
getTenants pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      t <- from $ table @TenantEntity
      orderBy [asc $ t ^. TenantEntityId]
      return t)
    pool
  return $ QuerySuccess $ map tenantFromEntity entities

-- | Get tenant by ID
getTenantById :: ConnectionPool -> Int64 -> IO (QueryResult Tenant)
getTenantById pool tid = do
  result <- liftIO $ runSqlPool
    (selectOne $ do
      t <- from $ table @TenantEntity
      where_ $ t ^. TenantEntityId ==. val (tenantKey tid)
      return t)
    pool
  return $ case result of
    Just entity -> QuerySuccess $ tenantFromEntity entity
    Nothing -> QueryError "Not Found"

-- | Get all stock movements (most recent first)
getStockMovements :: ConnectionPool -> IO (QueryResult [StockMovement])
getStockMovements pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      m <- from $ table @StockMovementEntity
      orderBy [desc $ m ^. StockMovementEntityMovementDate, desc $ m ^. StockMovementEntityId]
      return m)
    pool
  return $ QuerySuccess $ map stockMovementFromEntity entities

-- | Get stock movements by goods ID
getStockMovementsByGoods :: ConnectionPool -> Int64 -> IO (QueryResult [StockMovement])
getStockMovementsByGoods connPool gid = do
  entities <- liftIO $ runSqlPool
    (select $ do
      sm <- from $ table @StockMovementEntity
      where_ $ sm ^. StockMovementEntityGoodsId ==. val gid
      orderBy [desc $ sm ^. StockMovementEntityMovementDate, desc $ sm ^. StockMovementEntityId]
      return sm)
    connPool
  return $ QuerySuccess $ map stockMovementFromEntity entities

-- | Get currencies
getCurrencies :: ConnectionPool -> IO (QueryResult [Currency])
getCurrencies pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      c <- from $ table @CurrencyEntity
      orderBy [desc $ c ^. CurrencyEntityIsDefault, asc $ c ^. CurrencyEntityCode]
      return c)
    pool
  return $ QuerySuccess $ map currencyFromEntity entities

-- | Get all timesheets
getTimesheets :: ConnectionPool -> IO (QueryResult [Timesheet])
getTimesheets pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
      t <- from $ table @TimesheetEntity
      orderBy [desc $ t ^. TimesheetEntityDate]
      return t)
    pool
  return $ QuerySuccess $ map timesheetFromEntity entities
