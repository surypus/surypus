{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

{-@ LIQUID "--reflection" @-}

module System.Hardware where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

{-@ type PosInt = {v:Int | v > 0} @-}
{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ type TimeOrder a = {v:a | v >= v} @-}

data HardwareStatus
  = HSPlanned
  | HSInProgress
  | HSCompleted
  | HSCancelled
  deriving (Show, Eq, Enum, Read, Generic)

instance ToJSON HardwareStatus

instance FromJSON HardwareStatus

{-@ data HardwareLoad = HardwareLoad
  { hlId         :: Maybe Int64
  , hlResourceId :: PosInt
  , hlStartTime  :: UTCTime
  , hlEndTime    :: UTCTime
  , hlTechId     :: PosInt
  , hlQuantity   :: NonNeg
  , hlStatus     :: HardwareStatus
  } @-}
data HardwareLoad = HardwareLoad
  { hlId :: Maybe Int64,
    hlResourceId :: Int64,
    hlStartTime :: UTCTime,
    hlEndTime :: UTCTime,
    hlTechId :: Int64,
    hlQuantity :: Double,
    hlStatus :: HardwareStatus
  }
  deriving (Show, Eq, Generic)

instance ToJSON HardwareLoad

instance FromJSON HardwareLoad

validateHardwareLoad :: HardwareLoad -> Either Text HardwareLoad
validateHardwareLoad h
  | hlQuantity h <= 0 = Left "quantity must be positive"
  | hlEndTime h <= hlStartTime h = Left "end time must be after start"
  | hlResourceId h <= 0 = Left "resource id must be positive"
  | hlTechId h <= 0 = Left "tech id must be positive"
  | otherwise = Right h
