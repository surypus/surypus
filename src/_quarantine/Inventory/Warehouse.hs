{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Inventory.Warehouse
  ( Warehouse  (..)
  , WarehouseType  (..)
  , CreateWarehouseRequest  (..)
  , UpdateWarehouseRequest  (..)
  , WarehouseResult  (..)
  , createWarehouse
  , readWarehouse
  , updateWarehouse
  , deleteWarehouse
  , listWarehouses
  , findWarehouseByCode
  , countWarehouses
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)
import Data.Maybe (fromMaybe)

-- | Warehouse type (location classification)
data WarehouseType = MainWarehouse | BranchWarehouse | RetailShop | OtherWarehouse
  deriving (Show, Eq, Enum, Generic)

instance ToJSON WarehouseType
instance FromJSON WarehouseType

-- | Warehouse record
data Warehouse = Warehouse
  { wId :: Int64
  , wCode :: Text
  , wName :: Text
  , wType :: WarehouseType
  , wAddress :: Maybe Text
  , wCapacity :: Maybe Double
  } deriving (Show, Eq, Generic)

instance ToJSON Warehouse
instance FromJSON Warehouse

-- | Create request
data CreateWarehouseRequest = CreateWarehouseRequest
  { cwrCode :: Text
  , cwrName :: Text
  , cwrType :: WarehouseType
  , cwrAddress :: Maybe Text
  , cwrCapacity :: Maybe Double
  } deriving (Show, Eq, Generic)

instance ToJSON CreateWarehouseRequest
instance FromJSON CreateWarehouseRequest

-- | Update request
data UpdateWarehouseRequest = UpdateWarehouseRequest
  { uwrName :: Maybe Text
  , uwrAddress :: Maybe Text
  , uwrCapacity :: Maybe Double
  } deriving (Show, Eq, Generic)

instance ToJSON UpdateWarehouseRequest
instance FromJSON UpdateWarehouseRequest

-- | Result wrapper
data WarehouseResult a = WarehouseSuccess a | WarehouseError Text
  deriving (Show, Eq, Generic)

instance ToJSON a => ToJSON (WarehouseResult a)
instance FromJSON a => FromJSON (WarehouseResult a)

-- | Create new warehouse (pure, on list)
createWarehouse :: [Warehouse] -> CreateWarehouseRequest -> WarehouseResult Warehouse
createWarehouse existing req
  | T.null (cwrCode req) = WarehouseError "Code required"
  | T.null (cwrName req) = WarehouseError "Name required"
  | any (\u -> wCode u == cwrCode req) existing = WarehouseError "Duplicate code"
  | otherwise =
      let newId = (maximum (0 : map wId existing)) + 1
          w = Warehouse
                { wId = newId
                , wCode = cwrCode req
                , wName = cwrName req
                , wType = cwrType req
                , wAddress = cwrAddress req
                , wCapacity = cwrCapacity req
                }
      in WarehouseSuccess w

-- | Read warehouse by id
readWarehouse :: [Warehouse] -> Int64 -> WarehouseResult Warehouse
readWarehouse whs wid = case filter (\u -> wId u == wid) whs of
  (u:_) -> WarehouseSuccess u
  [] -> WarehouseError "Not found"

-- | Update warehouse
updateWarehouse :: [Warehouse] -> Int64 -> UpdateWarehouseRequest -> WarehouseResult Warehouse
updateWarehouse whs wid req = case readWarehouse whs wid of
  WarehouseError e -> WarehouseError e
  WarehouseSuccess w ->
    let updated = w
          { wName = fromMaybe (wName w) (uwrName req)
          , wAddress = case uwrAddress req of
              Just v -> Just v
              Nothing -> wAddress w
          , wCapacity = case uwrCapacity req of
              Just v -> Just v
              Nothing -> wCapacity w
          }
    in WarehouseSuccess updated

-- | Delete (soft delete) - here we just mark name with suffix
deleteWarehouse :: [Warehouse] -> Int64 -> WarehouseResult Warehouse
deleteWarehouse whs wid = case readWarehouse whs wid of
  WarehouseError e -> WarehouseError e
  WarehouseSuccess w -> WarehouseSuccess (w { wName = T.append (wName w) " (archived)", wCapacity = Nothing })

-- | List warehouses
listWarehouses :: [Warehouse] -> WarehouseResult [Warehouse]
listWarehouses = WarehouseSuccess

-- | Find by code
findWarehouseByCode :: [Warehouse] -> Text -> Maybe Warehouse
findWarehouseByCode whs code = case filter (\u -> wCode u == code) whs of
  (u:_) -> Just u
  [] -> Nothing

-- | Count
countWarehouses :: [Warehouse] -> Int
countWarehouses = length
