{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Inventory.Goods
  ( -- * Types
    Goods   (..),
    GoodsStatus   (..),
    GoodsKind   (..),
    CreateGoodsRequest   (..),
    UpdateGoodsRequest   (..),
    GoodsOperationResult   (..),

    -- * Operations
    createGoods,
    readGoods,
    updateGoods,
    deleteGoods,
    listGoods,

    -- * Validation
    validateGoodsData,
    GoodsValidationError   (..),

    -- * Status management
    activateGoods,
    deactivateGoods,
    discontinueGoods,

    -- * Queries
    goodsByStatus,
    goodsByKind,
    findGoodsByCode,
    findGoodsByBarcode,
    countGoods,
    findGoodsByParent,
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Maybe (mapMaybe, fromMaybe)
import Control.Applicative ((<|>))
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)

-- | Goods kind (type)
data GoodsKind
  = Product
  | Service
  | Material
  | Component
  | Assembly
  | FinishedGood
  deriving (Show, Eq, Enum, Generic)

instance ToJSON GoodsKind
instance FromJSON GoodsKind

-- | Goods status
data GoodsStatus
  = GoodsActive
  | GoodsInactive
  | GoodsDiscontinued
  | GoodsArchived
  deriving (Show, Eq, Enum, Generic)

instance ToJSON GoodsStatus
instance FromJSON GoodsStatus

-- | Goods record
data Goods = Goods
  { gId :: Int64,
    gCode :: Text,
    gName :: Text,
    gFullName :: Maybe Text,
    gBarcode :: Maybe Text,
    gDescription :: Maybe Text,
    gKind :: GoodsKind,
    gStatus :: GoodsStatus,
    gUnitId :: Int64,
    gParentId :: Maybe Int64,
    gMinStock :: Double,
    gMaxStock :: Double,
    gWeight :: Maybe Double,
    gVolume :: Maybe Double,
    gManufacturer :: Maybe Text,
    gCountry :: Maybe Text,
    gCost :: Double,
    gMarkup :: Double,
    gActive :: Bool
  } deriving (Show, Eq, Generic)

instance ToJSON Goods
instance FromJSON Goods

-- | Request to create goods
data CreateGoodsRequest = CreateGoodsRequest
  { cgrCode :: Text,
    cgrName :: Text,
    cgrFullName :: Maybe Text,
    cgrBarcode :: Maybe Text,
    cgrDescription :: Maybe Text,
    cgrKind :: GoodsKind,
    cgrUnitId :: Int64,
    cgrParentId :: Maybe Int64,
    cgrMinStock :: Double,
    cgrMaxStock :: Double,
    cgrWeight :: Maybe Double,
    cgrVolume :: Maybe Double,
    cgrCost :: Double
  } deriving (Show, Eq, Generic)

instance ToJSON CreateGoodsRequest
instance FromJSON CreateGoodsRequest

-- | Request to update goods
data UpdateGoodsRequest = UpdateGoodsRequest
  { ugrName :: Maybe Text,
    ugrDescription :: Maybe Text,
    ugrBarcode :: Maybe Text,
    ugrStatus :: Maybe GoodsStatus,
    ugrMinStock :: Maybe Double,
    ugrMaxStock :: Maybe Double,
    ugrCost :: Maybe Double,
    ugrMarkup :: Maybe Double
  } deriving (Show, Eq, Generic)

instance ToJSON UpdateGoodsRequest
instance FromJSON UpdateGoodsRequest

-- | Validation errors
data GoodsValidationError
  = InvalidGoodsCode
  | InvalidGoodsName
  | InvalidBarcode
  | InvalidMinMax
  | InvalidCost
  | DuplicateCode Text
  | DuplicateBarcode Text
  | GoodsNotFound Int64
  | ParentGoodsNotFound Int64
  deriving (Show, Eq, Generic)

instance ToJSON GoodsValidationError
instance FromJSON GoodsValidationError

-- | Operation result
data GoodsOperationResult a
  = GoodsSuccess a
  | GoodsError GoodsValidationError
  | GoodsConflict Text
  deriving (Show, Eq, Generic)

instance (ToJSON a) => ToJSON (GoodsOperationResult a)
instance (FromJSON a) => FromJSON (GoodsOperationResult a)

-- | Validate goods data
validateGoodsData :: CreateGoodsRequest -> [GoodsValidationError]
validateGoodsData req = mapMaybe id
  [ if T.null (cgrCode req) then Just InvalidGoodsCode else Nothing
  , if T.null (cgrName req) then Just InvalidGoodsName else Nothing
  , if cgrMinStock req < 0 || cgrMaxStock req < 0 then Just InvalidMinMax else Nothing
  , if cgrMinStock req > cgrMaxStock req then Just InvalidMinMax else Nothing
  , if cgrCost req < 0 then Just InvalidCost else Nothing
  , case cgrBarcode req of
      Just bc -> if T.null bc then Just InvalidBarcode else Nothing
      Nothing -> Nothing
  ]

-- | Check for duplicates
checkDuplicateGoods :: [Goods] -> CreateGoodsRequest -> Maybe GoodsValidationError
checkDuplicateGoods goods req = case findGoodsByCode goods (cgrCode req) of
  Just _ -> Just (DuplicateCode (cgrCode req))
  Nothing -> case cgrBarcode req of
    Just bc -> case findGoodsByBarcode goods bc of
      Just _ -> Just (DuplicateBarcode bc)
      Nothing -> Nothing
    Nothing -> Nothing

-- | Create new goods
createGoods :: [Goods] -> CreateGoodsRequest -> GoodsOperationResult Goods
createGoods goods req =
  case validateGoodsData req of
    errors@(_:_) -> GoodsError (head errors)
    [] -> case checkDuplicateGoods goods req of
      Just err -> GoodsConflict (T.pack (show err))
      Nothing ->
        let newId = (maximum (map gId goods) `max` 0) + 1
            newGoods = Goods
              { gId = newId
              , gCode = cgrCode req
              , gName = cgrName req
              , gFullName = cgrFullName req
              , gBarcode = cgrBarcode req
              , gDescription = cgrDescription req
              , gKind = cgrKind req
              , gStatus = GoodsActive
              , gUnitId = cgrUnitId req
              , gParentId = cgrParentId req
              , gMinStock = cgrMinStock req
              , gMaxStock = cgrMaxStock req
              , gWeight = cgrWeight req
              , gVolume = cgrVolume req
              , gManufacturer = Nothing
              , gCountry = Nothing
              , gCost = cgrCost req
              , gMarkup = 0.20
              , gActive = True
              }
        in GoodsSuccess newGoods

-- | Read goods by ID
readGoods :: [Goods] -> Int64 -> GoodsOperationResult Goods
readGoods goods gid = case [g | g <- goods, gId g == gid] of
  [] -> GoodsError (GoodsNotFound gid)
  (g:_) -> GoodsSuccess g

-- | Update goods
updateGoods :: [Goods] -> Int64 -> UpdateGoodsRequest -> GoodsOperationResult Goods
updateGoods goods gid req = case readGoods goods gid of
  GoodsSuccess g ->
    let updated = g
          { gName = fromMaybe (gName g) (ugrName req)
          , gDescription = ugrDescription req <|> gDescription g
          , gBarcode = ugrBarcode req <|> gBarcode g
          , gStatus = fromMaybe (gStatus g) (ugrStatus req)
          , gMinStock = fromMaybe (gMinStock g) (ugrMinStock req)
          , gMaxStock = fromMaybe (gMaxStock g) (ugrMaxStock req)
          , gCost = fromMaybe (gCost g) (ugrCost req)
          , gMarkup = fromMaybe (gMarkup g) (ugrMarkup req)
          }
    in GoodsSuccess updated
  err -> err

-- | Delete goods (soft delete)
deleteGoods :: [Goods] -> Int64 -> GoodsOperationResult Goods
deleteGoods goods gid = case readGoods goods gid of
  GoodsSuccess g ->
    let deleted = g { gStatus = GoodsArchived, gActive = False }
    in GoodsSuccess deleted
  err -> err

-- | List all goods
listGoods :: [Goods] -> GoodsOperationResult [Goods]
listGoods = GoodsSuccess

-- | Activate goods
activateGoods :: Goods -> GoodsOperationResult Goods
activateGoods g = GoodsSuccess $ g
  { gStatus = GoodsActive
  , gActive = True
  }

-- | Deactivate goods
deactivateGoods :: Goods -> GoodsOperationResult Goods
deactivateGoods g = GoodsSuccess $ g
  { gStatus = GoodsInactive
  , gActive = False
  }

-- | Discontinue goods
discontinueGoods :: Goods -> GoodsOperationResult Goods
discontinueGoods g = GoodsSuccess $ g
  { gStatus = GoodsDiscontinued
  , gActive = False
  }

-- | Query by status
goodsByStatus :: GoodsStatus -> [Goods] -> [Goods]
goodsByStatus status goods = [g | g <- goods, gStatus g == status]

-- | Query by kind
goodsByKind :: [Goods] -> GoodsKind -> [Goods]
goodsByKind goods kind = [g | g <- goods, gKind g == kind]

-- | Find by code
findGoodsByCode :: [Goods] -> Text -> Maybe Goods
findGoodsByCode goods code = case [g | g <- goods, gCode g == code] of
  [] -> Nothing
  (g:_) -> Just g

-- | Find by barcode
findGoodsByBarcode :: [Goods] -> Text -> Maybe Goods
findGoodsByBarcode goods barcode = case [g | g <- goods, gBarcode g == Just barcode] of
  [] -> Nothing
  (g:_) -> Just g

-- | Find parent goods
findGoodsByParent :: [Goods] -> Int64 -> [Goods]
findGoodsByParent goods parentId = [g | g <- goods, gParentId g == Just parentId]

-- | Count goods
countGoods :: [Goods] -> Int
countGoods = length

-- | Count active goods
countActiveGoods :: [Goods] -> Int
countActiveGoods = length . goodsByStatus GoodsActive

-- | Get goods requiring restocking
goodsForRestocking :: [Goods] -> [Goods]
goodsForRestocking goods =
  filter (\g -> gActive g && gStatus g == GoodsActive) goods

-- | Calculate total inventory value
totalInventoryValue :: [Goods] -> Double
totalInventoryValue goods =
  sum [gCost g * gMarkup g | g <- goods, gActive g]

-- | Get low stock items
lowStockItems :: [Goods] -> Double -> [Goods]
lowStockItems goods threshold =
  filter (\g -> gMinStock g > threshold) goods
