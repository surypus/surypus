{-@ LIQUID "--reflection" @-}

module Surypus.Refined
  ( -- * Functions
    clampNonNeg,
    clampPercentage,
    isNonNeg,
    combineNonNeg
  ) where

{-@ type NonNegDouble = {v:Double | v >= 0} @-}
{-@ type PositiveDouble = {v:Double | v > 0} @-}
{-@ type Percentage = {v:Double | 0 <= v && v <= 100} @-}
{-@ type NonNegInt = {v:Int | v >= 0} @-}
{-@ type NonNegInt64 = {v:Int64 | v >= 0} @-}

{-@ clampNonNeg :: x:Double -> {v:Double | v >= 0} @-}
clampNonNeg :: Double -> Double
clampNonNeg = max 0

{-@ clampPercentage :: x:Double -> {v:Double | 0 <= v && v <= 100} @-}
clampPercentage :: Double -> Double
clampPercentage x
  | x < 0 = 0
  | x > 100 = 100
  | otherwise = x

{-@ isNonNeg :: Double -> Bool @-}
isNonNeg :: Double -> Bool
isNonNeg = (>= 0)

{-@ combineNonNeg :: Double -> Double -> {v:Double | v >= 0} @-}
combineNonNeg :: Double -> Double -> Double
combineNonNeg a b = clampNonNeg (a + b)
