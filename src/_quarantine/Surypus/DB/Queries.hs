module Surypus.DB.Queries
  ( listPersons
  , getPersonById
  , listBills
  , getBillById
  , listTaxRates
  , getTaxRateById
  ) where

import Data.Int (Int64)
import Database.Persist.Sql (runSqlPool, toSqlKey)
import Database.Persist.Postgresql (ConnectionPool)
import qualified Database.Persist as P
import DAL.Types (PersonEntity(..), BillEntity(..), TaxEntity(..))

listPersons :: ConnectionPool -> Int -> Int -> IO [P.Entity PersonEntity]
listPersons pool offset limit =
  runSqlPool (P.selectList [] [P.OffsetBy offset, P.LimitTo limit]) pool

getPersonById :: ConnectionPool -> Int64 -> IO (Maybe PersonEntity)
getPersonById pool pid =
  runSqlPool (P.get (toSqlKey pid)) pool

listBills :: ConnectionPool -> Int -> Int -> IO [P.Entity BillEntity]
listBills pool offset limit =
  runSqlPool
    (P.selectList [] [P.OffsetBy offset, P.LimitTo limit])
    pool

getBillById :: ConnectionPool -> Int64 -> IO (Maybe BillEntity)
getBillById pool bid =
  runSqlPool (P.get (toSqlKey bid)) pool

listTaxRates :: ConnectionPool -> IO [P.Entity TaxEntity]
listTaxRates = runSqlPool (P.selectList [] [])

getTaxRateById :: ConnectionPool -> Int64 -> IO (Maybe TaxEntity)
getTaxRateById pool tid =
  runSqlPool (P.get (toSqlKey tid)) pool
