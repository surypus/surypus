{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.AccMask - Enhanced accounting mask with type safety
-- This module provides type-safe accounting masks for document processing
module Finance.AccMask where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import GHC.Generics (Generic)

-- | Accounting mask status
data AccMaskStatus
  = AMSActive     -- Активна (active)
  | AMSInactive   -- Неактивна (inactive)
  | AMSExpired    -- Истёкла (expired)
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Enhanced accounting mask with validation
data AccMask = AccMask
  { amId          :: Int64
  , amMaskCode    :: Text
  , amStartDate   :: Day
  , amEndDate     :: Maybe Day      -- Nothing = open-ended
  , amDescription :: Text
  , amStatus      :: AccMaskStatus
  , amPriority    :: Int            -- Priority order
  , amIsSystem    :: Bool           -- System mask (cannot be deleted)
  }
  deriving (Show, Eq, Generic)

-- | Mask code type
type MaskCode = Text
type AccMaskId = Int64

-- | Create a new accounting mask
createAccMask :: Int64 -> Text -> Day -> Maybe Day -> Text -> AccMaskStatus -> Int -> Bool -> AccMask
createAccMask id code start end desc status priority isSystem =
  AccMask id code start end desc status priority isSystem

-- | Check if mask is active on given date
isMaskActive :: AccMask -> Day -> Bool
isMaskActive mask date = amStatus mask == AMSActive
  && amStartDate mask <= date
  && maybe True (>= date) (amEndDate mask)

-- | Validate mask code format (must be alphanumeric, 1-10 chars)
validateMaskCode :: Text -> Either Text Text
validateMaskCode code
  | T.length code == 0 || T.length code > 10 = Left "Mask code must be 1-10 characters"
  | not (T.all (\c -> T.any (== c) (T.pack "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")) code) = Left "Mask code must be alphanumeric"
  | otherwise = Right code

-- | Convert mask to JSON
toJSONMask :: AccMask -> Text
toJSONMask mask = T.pack $ show mask