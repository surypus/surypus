-- Minimal stub for inventory document docs used in integration tests
-- Represents a simple inventory document with a type string
module Surypus.API.Documents.InventoryDocs where

data InventoryDoc = InventoryDoc
  { invDocType :: String
  }
  deriving (Show, Eq)
