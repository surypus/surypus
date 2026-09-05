{-# LANGUAGE OverloadedStrings #-}
module Science.ML.Features
  ( FeatureExtractor
  , extractFeatures
  , SalesFeatures(..)
  ) where

import Data.Time (Day)

-- | Feature vector for ML model
data SalesFeatures = SalesFeatures
  { sfItemId :: Int
  , sfDate :: Day
  , sfQuantity :: Double
  , sfPrice :: Double
  , sfDayOfWeek :: Int
  , sfDayOfMonth :: Int
  , sfIsWeekend :: Bool
  , sfRollingAvg7 :: Double
  , sfRollingAvg30 :: Double
  } deriving (Eq, Show)

-- | Type for feature extraction
type FeatureExtractor = Int -> Day -> [(Day, Double)] -> SalesFeatures

-- | Extract features from historical data
extractFeatures :: FeatureExtractor
extractFeatures itemId date history = SalesFeatures
  { sfItemId = itemId
  , sfDate = date
  , sfQuantity = 0
  , sfPrice = 0
  , sfDayOfWeek = 0
  , sfDayOfMonth = 0
  , sfIsWeekend = False
  , sfRollingAvg7 = 0
  , sfRollingAvg30 = 0
  }