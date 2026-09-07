{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

{-@ LIQUID "--reflection" @-}

module Production.Types
  ( TechCard   (..),
    TechLine   (..),
    WorkOrder   (..),
    WorkOrderStatusCode   (..),
    mkWorkOrder,
    validateTechCard,
    validateTechLine,
    validateWorkOrderCore,
    toWorkOrderStatus
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import GHC.Generics (Generic)

{-@ type NonNegQty = {v:Double | v >= 0} @-}
{-@ type NonNegCost = {v:Double | v >= 0} @-}

{-@ data TechCard = TechCard
  { tcId :: Maybe Int64
  , tcGoodsId :: Int64
  , tcName :: Text
  , tcVersion :: Text
  , tcStatus :: {v:Int | v >= 0 && v <= 2}
  , tcCreatedAt :: UTCTime
  , tcUpdatedAt :: UTCTime
  , tcCreatedBy :: Maybe Text
  } @-}
data TechCard = TechCard
  { tcId :: Maybe Int64,
    tcGoodsId :: Int64,
    tcName :: Text,
    tcVersion :: Text,
    tcStatus :: Int,
    tcCreatedAt :: UTCTime,
    tcUpdatedAt :: UTCTime,
    tcCreatedBy :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON TechCard

instance FromJSON TechCard

{-@ data TechLine = TechLine
  { tlId :: Maybe Int64
  , tlTechCardId :: Int64
  , tlLineNum :: Int
  , tlGoodsId :: Int64
  , tlQtyPlan :: NonNegQty
  , tlUnitId :: Maybe Int64
  , tlScrapPercent :: {v:Double | v >= 0.0 && v <= 100.0}
  , tlNotes :: Maybe Text
  , tlCreatedAt :: UTCTime
  , tlUpdatedAt :: UTCTime
  , tlCreatedBy :: Maybe Text
  } @-}
data TechLine = TechLine
  { tlId :: Maybe Int64,
    tlTechCardId :: Int64,
    tlLineNum :: Int,
    tlGoodsId :: Int64,
    tlQtyPlan :: Double,
    tlUnitId :: Maybe Int64,
    tlScrapPercent :: Double,
    tlNotes :: Maybe Text,
    tlCreatedAt :: UTCTime,
    tlUpdatedAt :: UTCTime,
    tlCreatedBy :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON TechLine

instance FromJSON TechLine

{-@ data WorkOrderStatusCode = WODraft | WOReleased | WOInProgress | WOCompleted | WOCancelled @-}
data WorkOrderStatusCode
  = WODraft
  | WOReleased
  | WOInProgress
  | WOCompleted
  | WOCancelled
  deriving (Eq, Show, Enum, Generic)

instance ToJSON WorkOrderStatusCode

instance FromJSON WorkOrderStatusCode

{-@ data WorkOrder = WorkOrder
  { woId :: Maybe Int64
  , woCode :: Text
  , woGoodsId :: Int64
  , woTechCardId :: Maybe Int64
  , woQtyPlan :: NonNegQty
  , woQtyReleased :: NonNegQty
  , woStatus :: {v:Int | v >= 0 && v <= 4}
  , woStartDate :: Maybe UTCTime
  , woEndDate :: Maybe UTCTime
  , woProcessorId :: Maybe Int64
  , woNotes :: Maybe Text
  , woCreatedAt :: UTCTime
  , woUpdatedAt :: UTCTime
  , woCreatedBy :: Maybe Text
  } @-}
data WorkOrder = WorkOrder
  { woId :: Maybe Int64,
    woCode :: Text,
    woGoodsId :: Int64,
    woTechCardId :: Maybe Int64,
    woQtyPlan :: Double,
    woQtyReleased :: Double,
    woStatus :: Int,
    woStartDate :: Maybe UTCTime,
    woEndDate :: Maybe UTCTime,
    woProcessorId :: Maybe Int64,
    woNotes :: Maybe Text,
    woCreatedAt :: UTCTime,
    woUpdatedAt :: UTCTime,
    woCreatedBy :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON WorkOrder

instance FromJSON WorkOrder

validateTechCard :: TechCard -> Either Text TechCard
validateTechCard tc@TechCard {..}
  | T.null (T.strip tcName) = Left "tech card name cannot be empty"
  | tcGoodsId <= 0 = Left "goods id must be positive"
  | tcStatus < 0 || tcStatus > 2 = Left "status must be 0 (draft), 1 (active), or 2 (archived)"
  | T.null (T.strip tcVersion) = Left "version cannot be empty"
  | otherwise = Right tc

validateTechLine :: TechLine -> Either Text TechLine
validateTechLine line@TechLine {..}
  | tlTechCardId <= 0 = Left "tech card id must be positive"
  | tlLineNum <= 0 = Left "line number must be positive"
  | tlGoodsId <= 0 = Left "goods id must be positive"
  | tlQtyPlan < 0 = Left "quantity must be non-negative"
   | maybe False (< 0) tlUnitId = Left "unit id must be positive when present"
  | tlScrapPercent < 0 || tlScrapPercent > 100 = Left "scrap percent must be between 0 and 100"
  | otherwise = Right line

validateWorkOrderCore :: WorkOrder -> Either Text WorkOrder
validateWorkOrderCore wo@WorkOrder {..}
  | T.null (T.strip woCode) = Left "work order code must be set"
  | woGoodsId <= 0 = Left "goods id must be positive"
  | woQtyPlan < 0 = Left "planned quantity must be non-negative"
  | woQtyReleased < 0 = Left "released quantity cannot be negative"
  | woQtyReleased > woQtyPlan = Left "released cannot exceed planned"
  | woStatus < 0 || woStatus > 4 = Left "status must be between 0 and 4"
  | otherwise = Right wo

mkWorkOrder :: Text -> Int64 -> Double -> UTCTime -> WorkOrder
mkWorkOrder code goodsId qtyPlan scheduled =
  let now = scheduled
  in WorkOrder Nothing code goodsId Nothing qtyPlan 0 0 (Just scheduled) Nothing Nothing Nothing now now Nothing

toWorkOrderStatus :: Int -> Maybe WorkOrderStatusCode
toWorkOrderStatus n
  | n >= 0 && n <= 4 = Just (toEnum n)
  | otherwise = Nothing
