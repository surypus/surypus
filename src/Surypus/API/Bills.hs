
{-# LANGUAGE OverloadedStrings #-}
-- | Surypus API Bills (Phase 1: stub)
module Surypus.API.Bills
  ( listBills
  , createBill
  , getBill
  , updateBill
  , deleteBill
  , postBill
  , updateBillStatus
  ) where

import DAL.Types (Bill(..), QueryResult(..))
import Data.Int (Int64)

-- | List bills (stub)
listBills :: Int64 -> IO (QueryResult [Bill])
listBills _ = return $ QuerySuccess []

-- | Create bill (stub)
createBill :: Bill -> IO (QueryResult Int64)
createBill _ = return $ QuerySuccess 0

-- | Get bill (stub)
getBill :: Int64 -> IO (QueryResult Bill)
getBill _ = return $ QueryError "Not found"

-- | Update bill (stub)
updateBill :: Bill -> IO (QueryResult ())
updateBill _ = return $ QuerySuccess ()

-- | Delete bill (stub)
deleteBill :: Int64 -> IO (QueryResult ())
deleteBill _ = return $ QuerySuccess ()

-- | Post bill (stub)
postBill :: Int64 -> IO (QueryResult ())
postBill _ = return $ QuerySuccess ()

-- | Update bill status (stub)
updateBillStatus :: Int64 -> String -> IO (QueryResult ())
updateBillStatus _ _ = return $ QuerySuccess ()
