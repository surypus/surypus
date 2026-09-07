{-# LANGUAGE DeriveGeneric #-}

-- | Production module - Manufacturing
module Production.Production
  ( TechLine   (..),
    Processor   (..),
    TSession   (..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)

-- | TechLine - Technology line (ingredient)
data TechLine = TechLine
  { tlId :: Int64,
    tlTechId :: Int64,
    tlGoodsId :: Int64, -- Input material
    tlQtty :: Double,
    tlFlags :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON TechLine

instance FromJSON TechLine

-- | Processor - Processing line
data Processor = Processor
  { procId :: Int64,
    procCode :: Text,
    procName :: Int64,
    procFlags :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON Processor

instance FromJSON Processor

-- | TSession - Processing session
data TSession = TSession
  { tsId :: Int64,
    tsProcessorId :: Int64,
    tsTechId :: Int64,
    tsStartTime :: Day,
    tsEndTime :: Maybe Day,
    tsOutputQtty :: Double,
    tsFlags :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON TSession

instance FromJSON TSession

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

-- prop_materialConsumptionNonNeg :: [(Int64, Double)] -> Property
-- prop_materialConsumptionNonNeg materials =
--   let valid = all (>= 0) (map snd materials)
--    in valid ==> forAll arbitrary $ \tech -> calcMaterialConsumption tech materials >= 0
