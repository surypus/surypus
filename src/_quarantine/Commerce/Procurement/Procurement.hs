{-# LANGUAGE DeriveGeneric #-}

module Commerce.Procurement.Procurement
  ( PurchaseRequest  (..),
    PurchaseRequestInput  (..),
    PurchaseOrder  (..),
    PurchaseOrderInput  (..),
    MRPlan  (..),
    MRPlanInput  (..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)

-- Purchase Request   (..)
data PurchaseRequest = PurchaseRequest
  { prId :: Int,
    prDate :: Day,
    prStatus :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON PurchaseRequest

instance FromJSON PurchaseRequest

data PurchaseRequestInput = PurchaseRequestInput
  { priDate :: Day,
    priStatus :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON PurchaseRequestInput

instance FromJSON PurchaseRequestInput

-- Purchase Order   (..)
data PurchaseOrder = PurchaseOrder
  { poId :: Int,
    poNumber :: Text,
    poDate :: Day,
    poStatus :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON PurchaseOrder

instance FromJSON PurchaseOrder

data PurchaseOrderInput = PurchaseOrderInput
  { poiNumber :: Text,
    poiDate :: Day,
    poiSupplierId :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON PurchaseOrderInput

instance FromJSON PurchaseOrderInput

-- MR Plan (MRP)
data MRPlan = MRPlan
  { mpId :: Int,
    mpPeriodStart :: Day,
    mpPeriodEnd :: Day,
    mpStatus :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON MRPlan

instance FromJSON MRPlan

data MRPlanInput = MRPlanInput
  { mpiPeriodStart :: Day,
    mpiPeriodEnd :: Day,
    mpiStatus :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON MRPlanInput

instance FromJSON MRPlanInput
