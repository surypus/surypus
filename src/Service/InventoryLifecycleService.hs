{-# LANGUAGE OverloadedStrings #-}
-- | Inventory Lifecycle Service (Phase 1: stub)
module Service.InventoryLifecycleService
  ( InventoryLifecycleService
  , createInventoryLifecycleService
  , postInventoryDocument
  ) where

import Data.Text (Text)
import Data.Time (Day)
import DAL.Database (ConnectionPool)

-- | Inventory lifecycle service (stub)
data InventoryLifecycleService = InventoryLifecycleService
  { ilServicePool :: !ConnectionPool
  }

-- | Create inventory lifecycle service (stub)
createInventoryLifecycleService :: ConnectionPool -> IO InventoryLifecycleService
createInventoryLifecycleService pool = return $ InventoryLifecycleService pool

-- | Post inventory document (stub)
postInventoryDocument :: InventoryLifecycleService -> Text -> IO (Either String ())
postInventoryDocument _ _doc = return $ Right ()
