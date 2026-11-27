{-# LANGUAGE OverloadedStrings #-}

-- | Surypus API Bills — bill endpoints over the DAL mutation layer.
module Surypus.API.Bills
  ( listBills
  , createBill
  , getBill
  , updateBill
  , deleteBill
  , postBill
  , updateBillStatus
  ) where

import Data.Int (Int64)
import qualified Data.Text as T
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Types (Bill(..), MutationResult(..), QueryResult(..))
import qualified DAL.MutationsORM as ORM
import qualified DAL.QueriesORM as Q

-- | List bills
listBills :: ConnectionPool -> IO (QueryResult [Bill])
listBills pool = Q.getBills pool

-- | Create a bill
createBill :: ConnectionPool -> Bill -> IO (QueryResult MutationResult)
createBill pool bill = do
  result <- ORM.createBill pool bill
  return $ case result of
    QuerySuccess k -> QuerySuccess (MutationResult True (Just k) "Bill created")
    QueryError e -> QueryError e
    QueryResults _ _ -> QueryError "Unexpected result"

-- | Get one bill by id
getBill :: ConnectionPool -> Int64 -> IO (QueryResult Bill)
getBill pool bid = Q.getBillById pool bid

-- | Update a bill
updateBill :: ConnectionPool -> Int64 -> Bill -> IO (QueryResult ())
updateBill pool _id bill = ORM.updateBill pool bill

-- | Delete a bill
deleteBill :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteBill pool bid = ORM.deleteBill pool bid

-- | Post a bill
postBill :: ConnectionPool -> Int64 -> IO (QueryResult ())
postBill pool bid = ORM.postBill pool bid

-- | Update bill status
updateBillStatus :: ConnectionPool -> Int64 -> Int -> IO (QueryResult ())
updateBillStatus pool bid status =
  ORM.updateBillStatus pool bid (T.pack (show status))
