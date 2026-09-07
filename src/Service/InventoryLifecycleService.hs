{-# LANGUAGE OverloadedStrings #-}

module Service.InventoryLifecycleService
  ( InventoryLifecycleService,
    createInventoryLifecycleService,
    postInventoryDocument,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import qualified Infrastructure.EventStore.Inventory as IEI
import qualified Service.InventoryService as InvS

-- | Inventory lifecycle service wrapping event-sourced inventory operations
data InventoryLifecycleService = InventoryLifecycleService
  { ilsEventStore :: IEI.InventoryEventStore
  , ilsNotify :: IEI.InventoryEvent -> IO ()
  }

-- | Create lifecycle service with given event store and notification callback
createInventoryLifecycleService :: IEI.InventoryEventStore -> (IEI.InventoryEvent -> IO ()) -> InventoryLifecycleService
createInventoryLifecycleService = InventoryLifecycleService

-- | Post an inventory document via the event-sourced inventory service
postInventoryDocument :: InventoryLifecycleService -> Text -> IO (Either Text InvS.InventoryDoc)
postInventoryDocument svc docType
  | T.null docType = pure (Left "Document type must be non-empty")
  | otherwise = do
      let today = read "2024-01-01" :: Day
          doc = InvS.InventoryDoc
            { InvS.idId = 0
            , InvS.idDocType = InvS.IDTReceipt
            , InvS.idStatus = InvS.IDSDraft
            , InvS.idDate = today
            , InvS.idLines = []
            , InvS.idDescription = docType
            }
      result <- InvS.postInventoryDoc (ilsEventStore svc) (ilsNotify svc) doc
      pure $ case result of
        Right () -> Right doc
        Left err -> Left err
