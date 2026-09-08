{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | DAL MutationsORM - raw SQL mutations for Surypus
module DAL.MutationsORM
  ( createPerson
  , updatePerson
  , deletePerson
  , createGoods
  , updateGoods
  , deleteGoods
  , createBill
  , updateBill
  , updateBillStatus
  , postBill
  , postBillWithAcc
  , addBillLine
  , deleteBillLine
  , deleteBill
  , createLocation
  , updateLocation
  , deleteLocation
  , updateStock
  , reserveStock
  , releaseStock
  , createOrder
  , updateOrderStatus
  , deleteOrder
  , createPayment
  , updatePayment
  , deletePayment
  , createUser
  , updateUser
  , createPrice
  , createTax
  , updateTax
  , deleteTax
  , createCurrency
  , updateCurrency
  , deleteCurrency
  , createAccPlan
  , updateAccPlan
  , deleteAccPlan
  , createAccTurn
  , updateAccTurn
  , deleteAccTurn
  , createEmployee
  , updateEmployee
  , deleteEmployee
  , createSalary
  , deleteSalary
  , createStockMovement
  , createTimesheet
  , updateTimesheet
  , deleteTimesheet
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime, getCurrentTime)
import Database.Persist.Sql (rawSql, rawExecute, Single(..), PersistValue(..))
import Database.Persist (PersistDay)
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Database (ConnectionPool, runDb)
import DAL.Schema
import DAL.Types
import DAL.Conversion

-- | Create a person
createPerson :: ConnectionPool -> Person -> IO (QueryResult Int64)
createPerson pool person = do
  now <- getCurrentTime
  let sql = "INSERT INTO persons (code, name, inn, kpp, person_type, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistText (personCode person)
    , PersistText (personName person)
    , maybe PersistNull PersistText (personInn person)
    , maybe PersistNull PersistText (personKpp person)
    , maybe PersistNull PersistText (personPersonType person)
    , maybe PersistNull PersistText (personStatus person)
    , PersistUTCTime now
    , PersistUTCTime now
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create person"

-- | Update a person
updatePerson :: ConnectionPool -> Person -> IO (QueryResult ())
updatePerson pool person = do
  now <- getCurrentTime
  let sql = "UPDATE persons SET code = ?, name = ?, inn = ?, kpp = ?, person_type = ?, status = ?, updated_at = ? WHERE id = ?"
  runDb pool $ rawExecute sql
    [ PersistText (personCode person)
    , PersistText (personName person)
    , maybe PersistNull PersistText (personInn person)
    , maybe PersistNull PersistText (personKpp person)
    , maybe PersistNull PersistText (personPersonType person)
    , maybe PersistNull PersistText (personStatus person)
    , PersistUTCTime now
    , PersistInt64 (personId person)
    ]
  return $ QuerySuccess ()

-- | Delete a person
deletePerson :: ConnectionPool -> Int64 -> IO (QueryResult ())
deletePerson pool id' = do
  let sql = "DELETE FROM persons WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create goods
createGoods :: ConnectionPool -> Goods -> IO (QueryResult Int64)
createGoods pool goods = do
  now <- getCurrentTime
  let sql = "INSERT INTO goods (code, name, full_name, barcode, unit_id, category_id, goods_type, goods_status, min_stock, max_stock, weight, volume, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistText (goodsCode goods)
    , PersistText (goodsName goods)
    , maybe PersistNull PersistText (goodsFullName goods)
    , maybe PersistNull PersistText (goodsBarcode goods)
    , maybe PersistNull (PersistInt64 . fromIntegral) (goodsUnitId goods)
    , maybe PersistNull (PersistInt64 . fromIntegral) (goodsCategoryId goods)
    , maybe PersistNull PersistText (goodsType goods)
    , maybe PersistNull PersistText (goodsStatus goods)
    , maybe PersistNull PersistDouble (goodsMinStock goods)
    , maybe PersistNull PersistDouble (goodsMaxStock goods)
    , maybe PersistNull PersistDouble (goodsWeight goods)
    , maybe PersistNull PersistDouble (goodsVolume goods)
    , PersistUTCTime now
    , PersistUTCTime now
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create goods"

-- | Update goods
updateGoods :: ConnectionPool -> Goods -> IO (QueryResult ())
updateGoods pool goods = do
  now <- getCurrentTime
  let sql = "UPDATE goods SET code = ?, name = ?, full_name = ?, barcode = ?, unit_id = ?, category_id = ?, goods_type = ?, goods_status = ?, min_stock = ?, max_stock = ?, weight = ?, volume = ?, updated_at = ? WHERE id = ?"
  runDb pool $ rawExecute sql
    [ PersistText (goodsCode goods)
    , PersistText (goodsName goods)
    , maybe PersistNull PersistText (goodsFullName goods)
    , maybe PersistNull PersistText (goodsBarcode goods)
    , maybe PersistNull (PersistInt64 . fromIntegral) (goodsUnitId goods)
    , maybe PersistNull (PersistInt64 . fromIntegral) (goodsCategoryId goods)
    , maybe PersistNull PersistText (goodsType goods)
    , maybe PersistNull PersistText (goodsStatus goods)
    , maybe PersistNull PersistDouble (goodsMinStock goods)
    , maybe PersistNull PersistDouble (goodsMaxStock goods)
    , maybe PersistNull PersistDouble (goodsWeight goods)
    , maybe PersistNull PersistDouble (goodsVolume goods)
    , PersistUTCTime now
    , PersistInt64 (goodsId goods)
    ]
  return $ QuerySuccess ()

-- | Delete goods
deleteGoods :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteGoods pool id' = do
  let sql = "DELETE FROM goods WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create a bill
createBill :: ConnectionPool -> Bill -> IO (QueryResult Int64)
createBill pool bill = do
  now <- getCurrentTime
  let sql = "INSERT INTO bills (bill_number, bill_date, customer_id, vendor_id, warehouse_id, currency_id, bill_status, bill_type, subtotal, tax_amount, total_amount, paid_amount, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ maybe PersistNull PersistText (billBillNumber bill)
    , maybe PersistNull PersistUTCTime (billBillDate bill)
    , maybe PersistNull PersistInt64 (billCustomerId bill)
    , maybe PersistNull PersistInt64 (billVendorId bill)
    , maybe PersistNull PersistInt64 (billWarehouseId bill)
    , maybe PersistNull PersistInt64 (billCurrencyId bill)
    , maybe PersistNull PersistText (billBillStatus bill)
    , maybe PersistNull PersistText (billBillType bill)
    , maybe PersistNull PersistDouble (billSubtotal bill)
    , maybe PersistNull PersistDouble (billTaxAmount bill)
    , maybe PersistNull PersistDouble (billTotalAmount bill)
    , maybe PersistNull PersistDouble (billPaidAmount bill)
    , maybe PersistNull PersistText (billNotes bill)
    , PersistUTCTime now
    , PersistUTCTime now
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create bill"

-- | Update a bill
updateBill :: ConnectionPool -> Bill -> IO (QueryResult ())
updateBill pool bill = do
  now <- getCurrentTime
  let sql = "UPDATE bills SET bill_number = ?, bill_date = ?, customer_id = ?, vendor_id = ?, warehouse_id = ?, currency_id = ?, bill_status = ?, bill_type = ?, subtotal = ?, tax_amount = ?, total_amount = ?, paid_amount = ?, notes = ?, updated_at = ? WHERE id = ?"
  runDb pool $ rawExecute sql
    [ maybe PersistNull PersistText (billBillNumber bill)
    , maybe PersistNull PersistUTCTime (billBillDate bill)
    , maybe PersistNull PersistInt64 (billCustomerId bill)
    , maybe PersistNull PersistInt64 (billVendorId bill)
    , maybe PersistNull PersistInt64 (billWarehouseId bill)
    , maybe PersistNull PersistInt64 (billCurrencyId bill)
    , maybe PersistNull PersistText (billBillStatus bill)
    , maybe PersistNull PersistText (billBillType bill)
    , maybe PersistNull PersistDouble (billSubtotal bill)
    , maybe PersistNull PersistDouble (billTaxAmount bill)
    , maybe PersistNull PersistDouble (billTotalAmount bill)
    , maybe PersistNull PersistDouble (billPaidAmount bill)
    , maybe PersistNull PersistText (billNotes bill)
    , PersistUTCTime now
    , PersistInt64 (billId bill)
    ]
  return $ QuerySuccess ()

-- | Update bill status
updateBillStatus :: ConnectionPool -> Int64 -> Text -> IO (QueryResult ())
updateBillStatus pool id' status = do
  now <- getCurrentTime
  let sql = "UPDATE bills SET bill_status = ?, updated_at = ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistText status, PersistUTCTime now, PersistInt64 id']
  return $ QuerySuccess ()

-- | Post a bill
postBill :: ConnectionPool -> Int64 -> IO (QueryResult ())
postBill pool id' = do
  now <- getCurrentTime
  let sql = "UPDATE bills SET bill_status = 'posted', updated_at = ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistUTCTime now, PersistInt64 id']
  return $ QuerySuccess ()

-- | Post a bill with accounting
postBillWithAcc :: ConnectionPool -> Int64 -> IO (QueryResult ())
postBillWithAcc pool id' = do
  now <- getCurrentTime
  let sql = "UPDATE bills SET bill_status = 'posted', updated_at = ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistUTCTime now, PersistInt64 id']
  return $ QuerySuccess ()

-- | Add a bill line
addBillLine :: ConnectionPool -> BillLine -> IO (QueryResult Int64)
addBillLine pool line = do
  let sql = "INSERT INTO bill_lines (bill_id, goods_id, qty, price, discount_amount, amount) VALUES (?, ?, ?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistInt64 (lineBillId line)
    , PersistInt64 (lineGoodId line)
    , PersistDouble (lineQtty line)
    , PersistDouble (linePrice line)
    , PersistDouble (lineDiscount line)
    , PersistDouble (lineAmount line)
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to add bill line"

-- | Delete a bill line
deleteBillLine :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteBillLine pool id' = do
  let sql = "DELETE FROM bill_lines WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Delete a bill
deleteBill :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteBill pool id' = do
  let sql = "DELETE FROM bills WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create a location
createLocation :: ConnectionPool -> Location -> IO (QueryResult Int64)
createLocation pool loc = do
  let sql = "INSERT INTO locations (code, name) VALUES (?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql [PersistText (locationCode loc), PersistText (locationName loc)]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create location"

-- | Update a location
updateLocation :: ConnectionPool -> Location -> IO (QueryResult ())
updateLocation pool loc = do
  let sql = "UPDATE locations SET code = ?, name = ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistText (locationCode loc), PersistText (locationName loc), PersistInt64 (locationId loc)]
  return $ QuerySuccess ()

-- | Delete a location
deleteLocation :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteLocation pool id' = do
  let sql = "DELETE FROM locations WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Update stock
updateStock :: ConnectionPool -> Int64 -> Double -> IO (QueryResult ())
updateStock pool goodsId qty = do
  let sql = "UPDATE goods SET stock = stock + ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistDouble qty, PersistInt64 goodsId]
  return $ QuerySuccess ()

-- | Reserve stock
reserveStock :: ConnectionPool -> Int64 -> Double -> IO (QueryResult ())
reserveStock pool goodsId qty = do
  let sql = "UPDATE goods SET reserved = reserved + ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistDouble qty, PersistInt64 goodsId]
  return $ QuerySuccess ()

-- | Release stock
releaseStock :: ConnectionPool -> Int64 -> Double -> IO (QueryResult ())
releaseStock pool goodsId qty = do
  let sql = "UPDATE goods SET reserved = reserved - ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistDouble qty, PersistInt64 goodsId]
  return $ QuerySuccess ()

-- | Create an order
createOrder :: ConnectionPool -> Order -> IO (QueryResult Int64)
createOrder pool order = do
  now <- getCurrentTime
  let sql = "INSERT INTO orders (code, name, doc_date, person_id, location_id, doc_type, total, discount_amount, tax_amount, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistText (orderCode order)
    , PersistText (orderName order)
    , PersistUTCTime (orderDate order)
    , maybe PersistNull PersistInt64 (orderPersonId order)
    , maybe PersistNull PersistInt64 (orderLocationId order)
    , maybe PersistNull PersistText (orderType order)
    , maybe PersistNull PersistDouble (orderTotal order)
    , maybe PersistNull PersistDouble (orderDiscount order)
    , maybe PersistNull PersistDouble (orderTax order)
    , PersistUTCTime now
    , PersistUTCTime now
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create order"

-- | Update order status
updateOrderStatus :: ConnectionPool -> Int64 -> Text -> IO (QueryResult ())
updateOrderStatus pool id' status = do
  now <- getCurrentTime
  let sql = "UPDATE orders SET status = ?, updated_at = ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistText status, PersistUTCTime now, PersistInt64 id']
  return $ QuerySuccess ()

-- | Delete an order
deleteOrder :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteOrder pool id' = do
  let sql = "DELETE FROM orders WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create a payment
createPayment :: ConnectionPool -> Payment -> IO (QueryResult Int64)
createPayment pool payment = do
  now <- getCurrentTime
  let sql = "INSERT INTO payments (bill_id, amount, payment_date, payment_method, created_at) VALUES (?, ?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistInt64 (paymentBillId payment)
    , PersistDouble (paymentAmount payment)
    , PersistUTCTime (paymentDate payment)
    , PersistText (paymentMethod payment)
    , PersistUTCTime now
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create payment"

-- | Update a payment
updatePayment :: ConnectionPool -> Payment -> IO (QueryResult ())
updatePayment pool payment = do
  let sql = "UPDATE payments SET bill_id = ?, amount = ?, payment_date = ?, payment_method = ? WHERE id = ?"
  runDb pool $ rawExecute sql
    [ PersistInt64 (paymentBillId payment)
    , PersistDouble (paymentAmount payment)
    , PersistUTCTime (paymentDate payment)
    , PersistText (paymentMethod payment)
    , PersistInt64 (paymentId payment)
    ]
  return $ QuerySuccess ()

-- | Delete a payment
deletePayment :: ConnectionPool -> Int64 -> IO (QueryResult ())
deletePayment pool id' = do
  let sql = "DELETE FROM payments WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create a user
createUser :: ConnectionPool -> User -> IO (QueryResult Int64)
createUser pool user = do
  now <- getCurrentTime
  let sql = "INSERT INTO users (name, password, email, person_id, status, tenant_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistText (userName user)
    , maybe PersistNull PersistText (userPassword user)
    , maybe PersistNull PersistText (userEmail user)
    , maybe PersistNull PersistInt64 (userPersonId user)
    , PersistText (userStatus user)
    , PersistInt64 (userTenantId user)
    , PersistUTCTime now
    , PersistUTCTime now
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create user"

-- | Update a user
updateUser :: ConnectionPool -> User -> IO (QueryResult ())
updateUser pool user = do
  now <- getCurrentTime
  let sql = "UPDATE users SET name = ?, password = ?, email = ?, person_id = ?, status = ?, tenant_id = ?, updated_at = ? WHERE id = ?"
  runDb pool $ rawExecute sql
    [ PersistText (userName user)
    , maybe PersistNull PersistText (userPassword user)
    , maybe PersistNull PersistText (userEmail user)
    , maybe PersistNull PersistInt64 (userPersonId user)
    , PersistText (userStatus user)
    , PersistInt64 (userTenantId user)
    , PersistUTCTime now
    , PersistInt64 (userId user)
    ]
  return $ QuerySuccess ()

-- | Create a price
createPrice :: ConnectionPool -> GoodsPrice -> IO (QueryResult Int64)
createPrice pool price = do
  let sql = "INSERT INTO goods_prices (goods_id, price_type, price, min_price, start_date, end_date) VALUES (?, ?, ?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistInt64 (goodsPriceGoodsId price)
    , maybe PersistNull PersistText (goodsPriceType price)
    , PersistDouble (goodsPricePrice price)
    , maybe PersistNull PersistDouble (goodsPriceMinPrice price)
    , maybe PersistNull PersistUTCTime (goodsPriceStartDate price)
    , maybe PersistNull PersistUTCTime (goodsPriceEndDate price)
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create price"

-- | Create a tax
createTax :: ConnectionPool -> Tax -> IO (QueryResult Int64)
createTax pool tax = do
  let sql = "INSERT INTO taxes (code, name, rate) VALUES (?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql [PersistText (taxCode tax), PersistText (taxName tax), PersistDouble (taxRate tax)]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create tax"

-- | Update a tax
updateTax :: ConnectionPool -> Tax -> IO (QueryResult ())
updateTax pool tax = do
  let sql = "UPDATE taxes SET code = ?, name = ?, rate = ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistText (taxCode tax), PersistText (taxName tax), PersistDouble (taxRate tax), PersistInt64 (taxId tax)]
  return $ QuerySuccess ()

-- | Delete a tax
deleteTax :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteTax pool id' = do
  let sql = "DELETE FROM taxes WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create a currency
createCurrency :: ConnectionPool -> Currency -> IO (QueryResult Int64)
createCurrency pool currency = do
  let sql = "INSERT INTO currencies (code, name) VALUES (?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql [PersistText (currencyCode currency), PersistText (currencyName currency)]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create currency"

-- | Update a currency
updateCurrency :: ConnectionPool -> Currency -> IO (QueryResult ())
updateCurrency pool currency = do
  let sql = "UPDATE currencies SET code = ?, name = ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistText (currencyCode currency), PersistText (currencyName currency), PersistInt64 (currencyId currency)]
  return $ QuerySuccess ()

-- | Delete a currency
deleteCurrency :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteCurrency pool id' = do
  let sql = "DELETE FROM currencies WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create an account plan
createAccPlan :: ConnectionPool -> AccPlan -> IO (QueryResult Int64)
createAccPlan pool acc = do
  let sql = "INSERT INTO acc_plans (code, name) VALUES (?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql [PersistText (accPlanCode acc), PersistText (accPlanName acc)]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create acc plan"

-- | Update an account plan
updateAccPlan :: ConnectionPool -> AccPlan -> IO (QueryResult ())
updateAccPlan pool acc = do
  let sql = "UPDATE acc_plans SET code = ?, name = ? WHERE id = ?"
  runDb pool $ rawExecute sql [PersistText (accPlanCode acc), PersistText (accPlanName acc), PersistInt64 (accPlanId acc)]
  return $ QuerySuccess ()

-- | Delete an account plan
deleteAccPlan :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteAccPlan pool id' = do
  let sql = "DELETE FROM acc_plans WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create an account turn
createAccTurn :: ConnectionPool -> AccTurn -> IO (QueryResult Int64)
createAccTurn pool turn = do
  let sql = "INSERT INTO acc_turns (debit_account, credit_account, amount, description) VALUES (?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistText (accTurnDebitAccount turn)
    , PersistText (accTurnCreditAccount turn)
    , PersistDouble (accTurnAmount turn)
    , maybe PersistNull PersistText (accTurnDescription turn)
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create acc turn"

-- | Update an account turn
updateAccTurn :: ConnectionPool -> AccTurn -> IO (QueryResult ())
updateAccTurn pool turn = do
  let sql = "UPDATE acc_turns SET debit_account = ?, credit_account = ?, amount = ?, description = ? WHERE id = ?"
  runDb pool $ rawExecute sql
    [ PersistText (accTurnDebitAccount turn)
    , PersistText (accTurnCreditAccount turn)
    , PersistDouble (accTurnAmount turn)
    , maybe PersistNull PersistText (accTurnDescription turn)
    , PersistInt64 (accTurnId turn)
    ]
  return $ QuerySuccess ()

-- | Delete an account turn
deleteAccTurn :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteAccTurn pool id' = do
  let sql = "DELETE FROM acc_turns WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create an employee
createEmployee :: ConnectionPool -> Employee -> IO (QueryResult Int64)
createEmployee pool emp = do
  let sql = "INSERT INTO employees (code, first_name, last_name) VALUES (?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistText (employeeCode emp)
    , PersistText (employeeFirstName emp)
    , maybe PersistNull PersistText (employeeLastName emp)
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create employee"

-- | Update an employee
updateEmployee :: ConnectionPool -> Employee -> IO (QueryResult ())
updateEmployee pool emp = do
  let sql = "UPDATE employees SET code = ?, first_name = ?, last_name = ? WHERE id = ?"
  runDb pool $ rawExecute sql
    [ PersistText (employeeCode emp)
    , PersistText (employeeFirstName emp)
    , maybe PersistNull PersistText (employeeLastName emp)
    , PersistInt64 (employeeId emp)
    ]
  return $ QuerySuccess ()

-- | Delete an employee
deleteEmployee :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteEmployee pool id' = do
  let sql = "DELETE FROM employees WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create a salary
createSalary :: ConnectionPool -> Salary -> IO (QueryResult Int64)
createSalary pool salary = do
  let sql = "INSERT INTO salaries (employee_id, amount, period) VALUES (?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistInt64 (salaryEmployeeId salary)
    , PersistDouble (salaryAmount salary)
    , PersistDay (salaryPeriod salary)
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create salary"

-- | Delete a salary
deleteSalary :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteSalary pool id' = do
  let sql = "DELETE FROM salaries WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()

-- | Create a stock movement
createStockMovement :: ConnectionPool -> StockMovement -> IO (QueryResult Int64)
createStockMovement pool movement = do
  let sql = "INSERT INTO stock_movements (goods_id, warehouse_id, movement_type, quantity, created_at) VALUES (?, ?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistInt64 (stockMovementGoodsId movement)
    , PersistInt64 (stockMovementWarehouseId movement)
    , PersistText (stockMovementType movement)
    , PersistDouble (stockMovementQty movement)
    , PersistUTCTime (stockMovementCreatedAt movement)
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create stock movement"

-- | Create a timesheet
createTimesheet :: ConnectionPool -> Timesheet -> IO (QueryResult Int64)
createTimesheet pool ts = do
  let sql = "INSERT INTO timesheets (employee_id, work_date, hours, created_at) VALUES (?, ?, ?, ?) RETURNING id"
  rows <- runDb pool $ rawSql sql
    [ PersistInt64 (timesheetEmployeeId ts)
    , PersistDay (timesheetWorkDate ts)
    , PersistDouble (timesheetHours ts)
    , PersistUTCTime (timesheetCreatedAt ts)
    ]
  case rows of
    (Single (PersistInt64 id') : _) -> return $ QuerySuccess id'
    _ -> return $ QueryError "Failed to create timesheet"

-- | Update a timesheet
updateTimesheet :: ConnectionPool -> Timesheet -> IO (QueryResult ())
updateTimesheet pool ts = do
  let sql = "UPDATE timesheets SET employee_id = ?, work_date = ?, hours = ? WHERE id = ?"
  runDb pool $ rawExecute sql
    [ PersistInt64 (timesheetEmployeeId ts)
    , PersistDay (timesheetWorkDate ts)
    , PersistDouble (timesheetHours ts)
    , PersistInt64 (timesheetId ts)
    ]
  return $ QuerySuccess ()

-- | Delete a timesheet
deleteTimesheet :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteTimesheet pool id' = do
  let sql = "DELETE FROM timesheets WHERE id = ?"
  runDb pool $ rawExecute sql [PersistInt64 id']
  return $ QuerySuccess ()
