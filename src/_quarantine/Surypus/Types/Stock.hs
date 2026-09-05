{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Surypus.Types.Stock
  ( StockItem (..),
    StockMovement (..),
    StockLevel (..),
    StockAdjustment (..),
    LowStockAlert (..),
  )
where

import Data.Aeson (FromJSON (..), Options (..), ToJSON (..), defaultOptions, genericParseJSON, genericToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import Surypus.Types.Common (camelTo2)

-- ═══════════════════════════════════════════════════════════════════════════
-- STOCK TYPES
-- ═══════════════════════════════════════════════════════════════════════════

data StockItem = StockItem
  { stockId :: !Int64,
    stockGoodId :: !Int64,
    stockLocationId :: !Int64,
    stockQuantity :: !Double,
    stockReserved :: !Double,
    stockMinLevel :: !(Maybe Double),
    stockMaxLevel :: !(Maybe Double),
    stockUpdatedAt :: !UTCTime
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON StockItem where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

instance FromJSON StockItem where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

data StockMovement = StockMovement
  { movementId :: !Int64,
    movementType :: !MovementType,
    movementGoodId :: !Int64,
    movementFromLocation :: !(Maybe Int64),
    movementToLocation :: !(Maybe Int64),
    movementQuantity :: !Double,
    movementReference :: !(Maybe Text),
    movementTimestamp :: !UTCTime
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON StockMovement where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 8}

instance FromJSON StockMovement where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 8}

data MovementType
  = Receipt
  | Issue
  | Transfer
  | Adjustment
  | Return
  deriving stock (Show, Eq, Generic, Enum, Bounded)

instance ToJSON MovementType

instance FromJSON MovementType

data StockLevel = StockLevel
  { levelGoodId :: !Int64,
    levelGoodName :: !Text,
    levelLocationId :: !Int64,
    levelLocationName :: !Text,
    levelAvailable :: !Double,
    levelReserved :: !Double,
    levelOnOrder :: !Double
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON StockLevel where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

instance FromJSON StockLevel where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

data StockAdjustment = StockAdjustment
  { adjId :: !Int64,
    adjStockItemId :: !Int64,
    adjOldQuantity :: !Double,
    adjNewQuantity :: !Double,
    adjReason :: !Text,
    adjUserId :: !Int64,
    adjTimestamp :: !UTCTime
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON StockAdjustment where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

instance FromJSON StockAdjustment where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 3}

data LowStockAlert = LowStockAlert
  { alertGoodId :: !Int64,
    alertGoodName :: !Text,
    alertCurrentStock :: !Double,
    alertMinLevel :: !Double,
    alertLocationId :: !Int64,
    alertSeverity :: !AlertSeverity
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON LowStockAlert where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

instance FromJSON LowStockAlert where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 5}

data AlertSeverity = Info | Warning | Critical
  deriving stock (Show, Eq, Generic, Enum, Bounded)

instance ToJSON AlertSeverity

instance FromJSON AlertSeverity

-- Remove duplicate helpers
