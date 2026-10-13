{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | DAL QueriesORM - raw SQL queries for Surypus
module DAL.QueriesORM
  ( personKey
  , goodsKey
  , billKey
  , locationKey
  , lotKey
  , tenantKey
  , taxKey
  , currencyKey
  , billLineFromEntity
  , employeeToDummyUser
  , documentTypeFromEntity
  , orderFromEntity
  , goodsPriceFromEntity
  , currencyFromEntity
  , keyToInt
  , ilike
  , getStockAll
  , getStockMovements
  , getStockMovementsByGoods
  , getLots
  , getLotById
  , getLotsByGoods
  , getLotsByLocation
  , getTenants
  , getTenantById
  , getLocations
  , getEmployees
  , getSalaries
  , getTimesheets
  , module DAL.Types
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime, Day)
import qualified Database.Persist.Sql as P (Entity(..), toSqlKey, Single(..), PersistValue(..), Key)
import Database.Persist.Sql (rawSql, PersistValue(PersistInt64))
import Database.Persist.Postgresql (ConnectionPool)
import Database.Persist.Sql (runSqlPool)
import DAL.Database (runDb)
import DAL.Schema hiding (Entity, BillLineEntity, DocumentTypeEntity, OrderHeadEntity, GoodsPriceEntity, CurrencyEntity)
import qualified DAL.Schema as S (BillLineEntity(..), DocumentTypeEntity(..), OrderHeadEntity(..), GoodsPriceEntity(..), CurrencyEntity(..), EmployeeEntity(..))
import DAL.Types hiding (PersonEntity, BillEntity, TaxEntity)
import DAL.Conversion hiding (keyToInt)

-- | Key helpers
personKey :: Int64 -> Int64
personKey = id

goodsKey :: Int64 -> Int64
goodsKey = id

billKey :: Int64 -> Int64
billKey = id

locationKey :: Int64 -> Int64
locationKey = id

lotKey :: Int64 -> Int64
lotKey = id

tenantKey :: Int64 -> Int64
tenantKey = id

taxKey :: Int64 -> Int64
taxKey = id

currencyKey :: Int64 -> Int64
currencyKey = id

-- | Convert key to Int64
keyToInt :: Int64 -> Int64
keyToInt = id

-- | ILIKE helper for raw SQL
ilike :: Text -> Text -> Text
ilike field val = field <> " ILIKE " <> val

-- | Additional conversion functions needed
billLineFromEntity :: Int64 -> S.BillLineEntity -> BillLine
billLineFromEntity lid e = BillLine
  { lineId = lid
  , lineBillId = S.billLineEntityBillId e
  , lineGoodId = S.billLineEntityGoodsId e
  , lineQtty = S.billLineEntityQtty e
  , linePrice = S.billLineEntityPrice e
  , lineDiscount = S.billLineEntityDiscountAmount e
  , lineAmount = S.billLineEntityAmount e
  }

employeeToDummyUser :: S.EmployeeEntity -> User
employeeToDummyUser e = User
  { userId = 0
  , userName = S.employeeEntityFirstName e <> maybe "" (" " <>) (S.employeeEntityLastName e)
  , userPassword = Nothing
  , userEmail = Nothing
  , userPersonId = Nothing
  , userStatus = "active"
  , userTenantId = 0
  }

documentTypeFromEntity :: Int64 -> S.DocumentTypeEntity -> DocumentRegisterType
documentTypeFromEntity tid e = DocumentRegisterType
  { drtId = tid
  , drtCode = S.documentTypeEntityCode e
  , drtName = S.documentTypeEntityName e
  , drtDescription = S.documentTypeEntityDescription e
  }

orderFromEntity :: Int64 -> S.OrderHeadEntity -> Order
orderFromEntity oid e = Order
  { orderId = oid
  , orderCode = S.orderHeadEntityCode e
  , orderName = S.orderHeadEntityName e
  , orderDate = S.orderHeadEntityDocDate e
  , orderPersonId = S.orderHeadEntityPersonId e
  , orderLocationId = S.orderHeadEntityLocationId e
  , orderType = S.orderHeadEntityDocType e
  , orderTotal = S.orderHeadEntityTotal e
  , orderDiscount = S.orderHeadEntityDiscountAmount e
  , orderTax = S.orderHeadEntityTaxAmount e
  }

goodsPriceFromEntity :: Int64 -> S.GoodsPriceEntity -> GoodsPrice
goodsPriceFromEntity gid e = GoodsPrice
  { goodsPriceId = gid
  , goodsPriceGoodsId = S.goodsPriceEntityGoodsId e
  , goodsPriceType = S.goodsPriceEntityPriceType e
  , goodsPricePrice = S.goodsPriceEntityPrice e
  , goodsPriceMinPrice = S.goodsPriceEntityMinPrice e
  , goodsPriceStartDate = S.goodsPriceEntityStartDate e
  , goodsPriceEndDate = S.goodsPriceEntityEndDate e
  }

currencyFromEntity :: Int64 -> S.CurrencyEntity -> Currency
currencyFromEntity cid e = Currency
  { currencyId = cid
  , currencyCode = S.currencyEntityCode e
  , currencyName = S.currencyEntityName e
  }

-- | Stock ----------------------------------------------------------------------

-- | All stock balances
getStockAll :: ConnectionPool -> IO (QueryResult [Stock])
getStockAll pool = do
  rows <- runDb pool $ rawSql
    "SELECT id, goods_id, location_id, qtty FROM stock ORDER BY id" []
  return $ QuerySuccess (map stockFromRow rows)

stockFromRow :: (P.Single Int64, P.Single Int64, P.Single Int64, P.Single Double) -> Stock
stockFromRow (P.Single sid, P.Single sgid, P.Single slid, P.Single sqtty) = Stock
  { stockId = sid
  , stockGoodsId = sgid
  , stockLocationId = slid
  , stockQtty = sqtty
  }

-- | All stock movements
getStockMovements :: ConnectionPool -> IO (QueryResult [StockMovement])
getStockMovements pool = do
  rows <- runDb pool $ rawSql
    "SELECT id, goods_id, warehouse_id, movement_type, quantity, created_at \
    \FROM stock_movements ORDER BY id" []
  return $ QuerySuccess (map stockMovementFromRow rows)

-- | Stock movements for one goods item
getStockMovementsByGoods :: ConnectionPool -> Int64 -> IO (QueryResult [StockMovement])
getStockMovementsByGoods pool goodsId = do
  rows <- runDb pool $ rawSql
    "SELECT id, goods_id, warehouse_id, movement_type, quantity, created_at \
    \FROM stock_movements WHERE goods_id = ? ORDER BY id" [PersistInt64 goodsId]
  return $ QuerySuccess (map stockMovementFromRow rows)

stockMovementFromRow
  :: (P.Single Int64, P.Single Int64, P.Single Int64, P.Single Text, P.Single Double, P.Single UTCTime)
  -> StockMovement
stockMovementFromRow (P.Single mid, P.Single mgid, P.Single mwid, P.Single mtype, P.Single mqty, P.Single mcreated) =
  StockMovement
    { stockMovementId = mid
    , stockMovementGoodsId = mgid
    , stockMovementWarehouseId = mwid
    , stockMovementType = mtype
    , stockMovementQty = mqty
    , stockMovementCreatedAt = mcreated
    }

-- | Lots -----------------------------------------------------------------------

-- | All stock lots
getLots :: ConnectionPool -> IO (QueryResult [Lot])
getLots pool = do
  rows <- runDb pool $ rawSql
    "SELECT id, goods_id, rest, cost FROM lot ORDER BY id" []
  return $ QuerySuccess (map lotFromRow rows)

-- | One lot by id
getLotById :: ConnectionPool -> Int64 -> IO (QueryResult Lot)
getLotById pool lid = do
  rows <- runDb pool $ rawSql
    "SELECT id, goods_id, rest, cost FROM lot WHERE id = ?" [PersistInt64 lid]
  return $ case rows of
    (row : _) -> QuerySuccess (lotFromRow row)
    [] -> QueryError "Lot not found"

-- | Lots for one goods item
getLotsByGoods :: ConnectionPool -> Int64 -> IO (QueryResult [Lot])
getLotsByGoods pool goodsId = do
  rows <- runDb pool $ rawSql
    "SELECT id, goods_id, rest, cost FROM lot WHERE goods_id = ? ORDER BY id" [PersistInt64 goodsId]
  return $ QuerySuccess (map lotFromRow rows)

-- | Lots stored at one location
getLotsByLocation :: ConnectionPool -> Int64 -> IO (QueryResult [Lot])
getLotsByLocation pool locationId = do
  rows <- runDb pool $ rawSql
    "SELECT id, goods_id, rest, cost FROM lot WHERE location_id = ? ORDER BY id" [PersistInt64 locationId]
  return $ QuerySuccess (map lotFromRow rows)

lotFromRow :: (P.Single Int64, P.Single Int64, P.Single Double, P.Single Double) -> Lot
lotFromRow (P.Single lid, P.Single lgid, P.Single lrest, P.Single lcost) = Lot
  { lotId = lid
  , lotGoodsId = lgid
  , lotRest = lrest
  , lotCost = lcost
  }

-- | Tenants --------------------------------------------------------------------

-- | All tenants
getTenants :: ConnectionPool -> IO (QueryResult [Tenant])
getTenants pool = do
  rows <- runDb pool $ rawSql
    "SELECT id, name, slug, schema_name, is_active FROM tenants ORDER BY id" []
  return $ QuerySuccess (map tenantFromRow rows)

-- | One tenant by id
getTenantById :: ConnectionPool -> Int64 -> IO (QueryResult Tenant)
getTenantById pool tid = do
  rows <- runDb pool $ rawSql
    "SELECT id, name, slug, schema_name, is_active FROM tenants WHERE id = ?" [PersistInt64 tid]
  return $ case rows of
    (row : _) -> QuerySuccess (tenantFromRow row)
    [] -> QueryError "Tenant not found"

tenantFromRow :: (P.Single Int64, P.Single Text, P.Single Text, P.Single Text, P.Single Bool) -> Tenant
tenantFromRow (P.Single tid, P.Single tname, P.Single tslug, P.Single tschema, P.Single tactive) = Tenant
  { tenantId = tid
  , tenantName = tname
  , tenantSlug = tslug
  , tenantSchemaName = tschema
  , tenantIsActive = tactive
  }

-- | Locations ------------------------------------------------------------------

-- | All warehouse locations
getLocations :: ConnectionPool -> IO (QueryResult [Location])
getLocations pool = do
  rows <- runDb pool $ rawSql
    "SELECT id, code, name FROM locations ORDER BY id" []
  return $ QuerySuccess (map locationFromRow rows)

locationFromRow :: (P.Single Int64, P.Single Text, P.Single Text) -> Location
locationFromRow (P.Single lid, P.Single lcode, P.Single lname) = Location
  { locationId = lid
  , locationCode = lcode
  , locationName = lname
  }

-- | Employees ------------------------------------------------------------------

-- | All employees
getEmployees :: ConnectionPool -> IO (QueryResult [Employee])
getEmployees pool = do
  rows <- runDb pool $ rawSql
    "SELECT id, code, first_name, last_name FROM employees ORDER BY id" []
  return $ QuerySuccess (map employeeFromRow rows)

employeeFromRow :: (P.Single Int64, P.Single Text, P.Single Text, P.Single (Maybe Text)) -> Employee
employeeFromRow (P.Single eid, P.Single ecode, P.Single efirst, P.Single elast) = Employee
  { employeeId = eid
  , employeeCode = ecode
  , employeeFirstName = efirst
  , employeeLastName = elast
  }

-- | Salaries -------------------------------------------------------------------

-- | All salary records
getSalaries :: ConnectionPool -> IO (QueryResult [Salary])
getSalaries pool = do
  rows <- runDb pool $ rawSql
    "SELECT id, employee_id, amount, period FROM salaries ORDER BY id" []
  return $ QuerySuccess (map salaryFromRow rows)

salaryFromRow :: (P.Single Int64, P.Single Int64, P.Single Double, P.Single Day) -> Salary
salaryFromRow (P.Single sid, P.Single seid, P.Single samount, P.Single speriod) = Salary
  { salaryId = sid
  , salaryEmployeeId = seid
  , salaryAmount = samount
  , salaryPeriod = speriod
  }

-- | Timesheets -----------------------------------------------------------------

-- | All timesheets
getTimesheets :: ConnectionPool -> IO (QueryResult [Timesheet])
getTimesheets pool = do
  rows <- runDb pool $ rawSql
    "SELECT id, employee_id, work_date, hours FROM timesheets ORDER BY id" []
  return $ QuerySuccess (map timesheetFromRow rows)

timesheetFromRow :: (P.Single Int64, P.Single Int64, P.Single Day, P.Single Double) -> Timesheet
timesheetFromRow (P.Single tid, P.Single teid, P.Single tdate, P.Single thours) = Timesheet
  { timesheetId = tid
  , timesheetEmployeeId = teid
  , timesheetDate = tdate
  , timesheetHours = thours
  , timesheetType = ""
  }
