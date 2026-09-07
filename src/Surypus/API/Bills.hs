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
listBills _ = return $ QueryResult [] 0

-- | Create bill (stub)
createBill :: Bill -> IO (QueryResult Int64)
createBill _ = return $ QueryResult [0] 1

-- | Get bill (stub)
getBill :: Int64 -> IO (QueryResult Bill)
getBill _ = return $ QueryResult [] 0

-- | Update bill (stub)
updateBill :: Bill -> IO (QueryResult ())
updateBill _ = return $ QueryResult [()] 1

-- | Delete bill (stub)
deleteBill :: Int64 -> IO (QueryResult ())
deleteBill _ = return $ QueryResult [()] 1

-- | Post bill (stub)
postBill :: Int64 -> IO (QueryResult ())
postBill _ = return $ QueryResult [()] 1

-- | Update bill status (stub)
updateBillStatus :: Int64 -> String -> IO (QueryResult ())
updateBillStatus _ _ = return $ QueryResult [()] 1
