{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Payroll
  ( getEmployees, getEmployeeById, getSalaries, getSalaryByEmployee
  , createEmployee, createSalary
  , updateEmployee, deleteEmployee, deleteSalary
  , getPayrollResults, getPayrollResultsByEmployee
  , getTimesheets, createTimesheet, updateTimesheet, deleteTimesheet
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Text (Text)
import Database.Persist.Sql (runSqlPool, rawSql, PersistValue(..), Single(..))
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Queries (getEmployeeById, getSalaryByEmployee)
import DAL.QueriesORM (getEmployees, getSalaries, getTimesheets)
import DAL.Mutations (createEmployee, createSalary, updateEmployee, deleteEmployee, deleteSalary)
import qualified DAL.MutationsORM as ORM
import DAL.Payroll (parsePayrollResult)
import DAL.Types (QueryResult(..), PayrollResult, MutationResult(..), Timesheet)

payrollResultColumns :: Text
payrollResultColumns =
  "SELECT id, tenant_id, period, employee_id, gross, deductions, net, \
  \income_tax, social_tax, advance, bonus, vacation_pay, sick_pay, \
  \total_to_pay, currency, version, created_by, created_at, updated_at \
  \FROM payroll_results"

chunksOf :: Int -> [a] -> [[a]]
chunksOf _ [] = []
chunksOf n xs = take n xs : chunksOf n (drop n xs)

getPayrollResults :: ConnectionPool -> IO (QueryResult [PayrollResult])
getPayrollResults pool = do
    rows <- liftIO $ runSqlPool
        (rawSql (payrollResultColumns <> " ORDER BY period DESC") [])
        pool :: IO [Single PersistValue]
    return $ QuerySuccess (map parsePayrollResult (chunksOf 19 rows))

getPayrollResultsByEmployee :: ConnectionPool -> Int64 -> IO (QueryResult [PayrollResult])
getPayrollResultsByEmployee pool eid = do
    rows <- liftIO $ runSqlPool
        (rawSql (payrollResultColumns <> " WHERE employee_id = ? ORDER BY period DESC") [PersistInt64 eid])
        pool :: IO [Single PersistValue]
    return $ QuerySuccess (map parsePayrollResult (chunksOf 19 rows))

createTimesheet :: ConnectionPool -> Timesheet -> IO (QueryResult MutationResult)
createTimesheet pool ts = do
    result <- ORM.createTimesheet pool ts
    return $ case result of
        QuerySuccess k -> QuerySuccess (MutationResult True (Just k) "Timesheet created")
        QueryError e -> QueryError e
        QueryResults _ _ -> QueryError "Unexpected result"

updateTimesheet :: ConnectionPool -> Int64 -> Timesheet -> IO (QueryResult MutationResult)
updateTimesheet pool tid ts = do
    result <- ORM.updateTimesheet pool ts
    return $ case result of
        QuerySuccess () -> QuerySuccess (MutationResult True (Just tid) "Timesheet updated")
        QueryError e -> QueryError e
        QueryResults _ _ -> QueryError "Unexpected result"

deleteTimesheet :: ConnectionPool -> Int64 -> IO (QueryResult MutationResult)
deleteTimesheet pool tid = do
    result <- ORM.deleteTimesheet pool tid
    return $ case result of
        QuerySuccess () -> QuerySuccess (MutationResult True (Just tid) "Timesheet deleted")
        QueryError e -> QueryError e
        QueryResults _ _ -> QueryError "Unexpected result"
