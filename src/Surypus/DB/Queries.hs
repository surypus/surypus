module Surypus.DB.Queries
  ( listPersons
  , getPersonById
  , listBills
  , getBillById
  , listTaxRates
  , getTaxRateById
  ) where

import Data.Int (Int64)
import DAL.Database (ConnectionPool, runDb)
import DAL.Types (PersonEntity(..), BillEntity(..), TaxEntity(..))

-- These are stub implementations that will be replaced with actual SQL queries
listPersons :: ConnectionPool -> Int -> Int -> IO [PersonEntity]
listPersons _ _ _ = return []

getPersonById :: ConnectionPool -> Int64 -> IO (Maybe PersonEntity)
getPersonById _ _ = return Nothing

listBills :: ConnectionPool -> Int -> Int -> IO [BillEntity]
listBills _ _ _ = return []

getBillById :: ConnectionPool -> Int64 -> IO (Maybe BillEntity)
getBillById _ _ = return Nothing

listTaxRates :: ConnectionPool -> IO [TaxEntity]
listTaxRates _ = return []

getTaxRateById :: ConnectionPool -> Int64 -> IO (Maybe TaxEntity)
getTaxRateById _ _ = return Nothing
