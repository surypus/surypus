{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.Payroll
  ( getEmployees, getEmployeeById, getSalaries, getSalaryByEmployee
  , createEmployee, createSalary
  , updateEmployee, deleteEmployee, deleteSalary
  , getPayrollResults, getPayrollResultsByEmployee
  , getTimesheets, createTimesheet, updateTimesheet, deleteTimesheet
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Database.Persist.Sql (runSqlPool)
import Database.Persist.Postgresql (ConnectionPool)
import qualified Database.Persist as P
import Data.Time.Calendar (Day)
import DAL.Queries (getEmployeeById, getSalaryByEmployee)
import DAL.QueriesORM (getEmployees, getSalaries, getTimesheets)
import DAL.Mutations (createEmployee, createSalary, updateEmployee, deleteEmployee, deleteSalary)
import DAL.MutationsORM (createTimesheet, updateTimesheet, deleteTimesheet)
import DAL.Conversion (payrollResultFromEntity)
import DAL.Schema
import DAL.Types (QueryResult(..), PayrollResult)

getPayrollResults :: ConnectionPool -> IO (QueryResult [PayrollResult])
getPayrollResults pool = do
    entities <- liftIO $ runSqlPool
        (P.selectList [] [P.Desc PayrollResultEntityPeriod]) pool
    return $ QuerySuccess (map payrollResultFromEntity entities)

getPayrollResultsByEmployee :: ConnectionPool -> Int64 -> IO (QueryResult [PayrollResult])
getPayrollResultsByEmployee pool eid = do
    entities <- liftIO $ runSqlPool
        (P.selectList [PayrollResultEntityEmployeeId P.==. eid] [P.Desc PayrollResultEntityPeriod]) pool
    return $ QuerySuccess (map payrollResultFromEntity entities)
