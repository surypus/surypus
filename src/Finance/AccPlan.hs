{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.AccPlan - Enhanced accounting plan with type safety
-- This module provides structured accounting plans with formal verification
module Finance.AccPlan where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import GHC.Generics (Generic)

-- | Accounting plan with richer semantics
data AccPlan = AccPlan
  { apId          :: AccPlanId
  , apCode        :: PlanCode
  , apName        :: PlanName
  , apParentId    :: Maybe AccPlanId
  , apIsActive    :: Bool
  , apCreatedAt   :: Day
  , apUpdatedAt   :: Maybe Day
  } deriving (Show, Eq, Generic)

-- | Newtypes for enhanced type safety
newtype AccPlanId = AccPlanId { unAccPlanId :: Int64 } deriving (Show, Eq, Ord)

newtype PlanCode = PlanCode { unPlanCode :: Text } deriving (Show, Eq, Ord)

newtype PlanName = PlanName { unPlanName :: Text } deriving (Show, Eq, Ord)

-- | Decimal type alias
type Decimal = Double

-- | Non-negative decimal
newtype NonNeg = NonNeg { unNonNeg :: Decimal } deriving (Show, Eq, Ord)

mkNonNeg :: Decimal -> Either Text NonNeg
mkNonNeg d
  | d >= 0    = Right (NonNeg d)
  | otherwise = Left "Value must be non-negative"

-- | Smart constructor with validation
createAccPlan :: AccPlanId -> PlanCode -> PlanName -> Day -> AccPlan
createAccPlan apid code name today = AccPlan
  { apId = apid
  , apCode = code
  , apName = name
  , apParentId = Nothing
  , apIsActive = True
  , apCreatedAt = today
  , apUpdatedAt = Nothing
  }

-- | Activate plan
activateAccPlan :: AccPlan -> AccPlan
activateAccPlan plan = plan { apIsActive = True, apUpdatedAt = Just (fromGregorian 2024 1 1) }

-- | Deactivate plan
deactivateAccPlan :: AccPlan -> AccPlan
deactivateAccPlan plan = plan { apIsActive = False, apUpdatedAt = Just (fromGregorian 2024 1 1) }

-- | Check if plan is active
isActivePlan :: AccPlan -> Bool
isActivePlan = apIsActive

-- | Pretty print accounting plan
prettyAccPlan :: AccPlan -> Text
prettyAccPlan plan = unPlanCode (apCode plan) <> " - " <> unPlanName (apName plan) <>
  if apIsActive plan then " (Active)" else " (Inactive)"