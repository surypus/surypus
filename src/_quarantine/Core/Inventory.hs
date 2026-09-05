-- | Inventory core types and invariants
{-# LANGUAGE OverloadedStrings #-}
{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple" @-}

module Core.Inventory where

{-@ type NonNegDouble = {v:Double | v >= 0} @-}

-- | Stock balance invariant: Rest = Initial + Receipt - Issue
{-@ stockBalance :: initial:NonNegDouble -> receipt:NonNegDouble -> issue:NonNegDouble -> {v:NonNegDouble | v == initial + receipt - issue && v >= 0} @-}
stockBalance :: Double -> Double -> Double -> Double
stockBalance initial receipt issue = initial + receipt - issue
