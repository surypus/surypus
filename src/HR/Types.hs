{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

{-@ LIQUID "--reflection" @-}

-- | HR / Payroll core types and invariants
module HR.Types
  ( SalaryCharge   (..),
    SalaryRecord   (..),
    SalarySummary   (..),
    SalaryChargeInput   (..),
    calcPeriodDays,
    calcSalaryPerDay,
    validateSalaryRecord,
    validateSalaryChargeInput,
    mkSalarySummary,
    mkSalaryCharge
  ) where

import Surypus.Refined (clampNonNeg)
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, diffDays)
import GHC.Generics (Generic)

{-@ type NonNegDouble = {v:Double | v >= 0} @-}

{-@ data SalaryCharge = SalaryCharge
  { scId :: Maybe Int64
  , scName :: Text
  , scCode :: Maybe Text
  , scFlags :: Int
  } @-}
data SalaryCharge = SalaryCharge
  { scId :: Maybe Int64,
    scName :: Text,
    scCode :: Maybe Text,
    scFlags :: Int
  }
  deriving (Eq, Show, Generic)

instance ToJSON SalaryCharge

instance FromJSON SalaryCharge

{-@ data SalaryRecord = SalaryRecord
  { srId :: Maybe Int64
  , srEmployeeId :: Int64
  , srChargeId :: Int64
  , srPeriodStart :: Day
  , srPeriodEnd :: Day
  , srAmount :: NonNegDouble
  , srExtObjId :: Maybe Int64
  , srLinkBillId :: Maybe Int64
  , srGenBillId :: Maybe Int64
  } @-}
data SalaryRecord = SalaryRecord
  { srId :: Maybe Int64,
    srEmployeeId :: Int64,
    srChargeId :: Int64,
    srPeriodStart :: Day,
    srPeriodEnd :: Day,
    srAmount :: Double,
    srExtObjId :: Maybe Int64,
    srLinkBillId :: Maybe Int64,
    srGenBillId :: Maybe Int64
  }
  deriving (Eq, Show, Generic)

instance ToJSON SalaryRecord

instance FromJSON SalaryRecord

{-@ data SalarySummary = SalarySummary
  { ssEmployeeId :: Int64
  , ssEmployeeName :: Text
  , ssPosition :: Text
  , ssTotal :: NonNegDouble
  } @-}
data SalarySummary = SalarySummary
  { ssEmployeeId :: Int64,
    ssEmployeeName :: Text,
    ssPosition :: Text,
    ssTotal :: Double
  }
  deriving (Eq, Show, Generic)

instance ToJSON SalarySummary

instance FromJSON SalarySummary

{-@ data SalaryChargeInput = SalaryChargeInput
  { sciName :: Text
  , sciCode :: Maybe Text
  , sciFlags :: Int
  } @-}
data SalaryChargeInput = SalaryChargeInput
  { sciName :: Text,
    sciCode :: Maybe Text,
    sciFlags :: Int
  }
  deriving (Eq, Show, Generic)

instance ToJSON SalaryChargeInput

instance FromJSON SalaryChargeInput

validateSalaryChargeInput :: SalaryChargeInput -> Either Text SalaryChargeInput
validateSalaryChargeInput input@SalaryChargeInput {..}
  | T.null (T.strip sciName) = Left "salary charge name cannot be empty"
  | sciFlags < 0 = Left "salary flags must be non-negative"
  | otherwise = Right input {sciName = T.strip sciName, sciCode = normalizeCode sciCode}
  where
    normalizeCode Nothing = Nothing
    normalizeCode (Just code) =
      let trimmed = T.strip code
       in if T.null trimmed then Nothing else Just (T.toUpper trimmed)

mkSalaryCharge :: SalaryChargeInput -> SalaryCharge
mkSalaryCharge SalaryChargeInput {..} = SalaryCharge Nothing sciName sciCode sciFlags

calcPeriodDays :: SalaryRecord -> Int
calcPeriodDays SalaryRecord {..} = fromIntegral $ diffDays srPeriodEnd srPeriodStart + 1

calcSalaryPerDay :: SalaryRecord -> Double
calcSalaryPerDay sr@SalaryRecord {..} =
  let days = fromIntegral (max 1 (calcPeriodDays sr))
   in clampNonNeg (srAmount / days)

validateSalaryRecord :: SalaryRecord -> Either Text SalaryRecord
validateSalaryRecord r@SalaryRecord {..}
  | srAmount < 0 = Left "salary amount must be non-negative"
  | srPeriodEnd < srPeriodStart = Left "period end must be on or after start"
  | srChargeId <= 0 = Left "charge id must be positive"
  | otherwise = Right r

mkSalarySummary :: Int64 -> Text -> Text -> Double -> SalarySummary
mkSalarySummary eid name position total = SalarySummary eid name position (clampNonNeg total)
