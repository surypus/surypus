{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Surypus.Types.Goods
  ( Goods (..),
    GoodsInput (..),
    GoodsSummary (..),
    Unit (..),
    GoodsCategory (..),
  )
where

import Data.Aeson (FromJSON (..), Options (..), ToJSON (..), defaultOptions, genericParseJSON, genericToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import Surypus.Types.Common (camelTo2)

-- ═══════════════════════════════════════════════════════════════════════════
-- GOODS TYPES (Товары и услуги)
-- ═══════════════════════════════════════════════════════════════════════════

data Goods = Goods
  { goodsId :: !Int64,
    goodsCode :: !(Maybe Text),
    goodsName :: !Text,
    goodsFullName :: !(Maybe Text),
    goodsBarcode :: !(Maybe Text),
    goodsUnitId :: !(Maybe Int64),
    goodsCategoryId :: !(Maybe Int64),
    goodsType :: !(Maybe Int),
    goodsStatus :: !(Maybe Int),
    goodsMinStock :: !(Maybe Double),
    goodsMaxStock :: !(Maybe Double),
    goodsWeight :: !(Maybe Double),
    goodsVolume :: !(Maybe Double),
    goodsCreatedAt :: !(Maybe UTCTime),
    goodsUpdatedAt :: !(Maybe UTCTime)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Goods where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

instance FromJSON Goods where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

data GoodsInput = GoodsInput
  { gInputName :: !Text,
    gInputCode :: !(Maybe Text),
    gInputBarcode :: !(Maybe Text),
    gInputUnitId :: !(Maybe Int64),
    gInputCategoryId :: !(Maybe Int64),
    gInputType :: !(Maybe Int),
    gInputMinStock :: !(Maybe Double),
    gInputMaxStock :: !(Maybe Double),
    gInputWeight :: !(Maybe Double),
    gInputVolume :: !(Maybe Double)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON GoodsInput where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 6}

instance FromJSON GoodsInput where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 6}

data GoodsSummary = GoodsSummary
  { gsId :: !Int64,
    gsCode :: !(Maybe Text),
    gsName :: !Text,
    gsUnitName :: !(Maybe Text),
    gsStockQuantity :: !Double,
    gsAvgPrice :: !(Maybe Double)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON GoodsSummary where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = drop 2}

instance FromJSON GoodsSummary where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = drop 2}

data Unit = Unit
  { unitId :: !Int64,
    unitCode :: !Text,
    unitName :: !Text,
    unitSymbol :: !(Maybe Text),
    unitType :: !(Maybe Int)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Unit where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

instance FromJSON Unit where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 4}

data GoodsCategory = GoodsCategory
  { catId :: !Int64,
    catName :: !Text,
    catParentId :: !(Maybe Int64),
    catLevel :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON GoodsCategory where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

instance FromJSON GoodsCategory where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}
