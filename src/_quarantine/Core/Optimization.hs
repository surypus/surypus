{-# LANGUAGE StrictData #-}
{-# LANGUAGE BangPatterns #-}

{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple"        @-}

{-@ type NonNegDouble = {v:Double | v >= 0.0} @-}
{-@ type Prob = {v:Double | v >= 0.0 && v <= 1.0} @-}

module Core.Optimization
  ( Direction(..)
  , Objective(..)
  , Constraint(..)
  , ConstraintType(..)
  , OptimizationState(..)
  , evaluateObjective
  , checkConstraint
  , optimize
  ) where

import Data.Text (Text)
import qualified Data.Map as M

-- | Objective function direction
data Direction
  = Maximize
  | Minimize
  deriving (Show, Eq)

-- | Optimization objective with variable coefficients
data Objective = Objective
  { objName :: !Text
  , objDirection :: !Direction
  , objCoefficients :: !(M.Map Text Double)
  } deriving (Show, Eq)

-- | Linear constraint
data Constraint = Constraint
  { conName :: !Text
  , conCoefficients :: !(M.Map Text Double)
  , conRHS :: !Double
  , conType :: !ConstraintType
  } deriving (Show, Eq)

data ConstraintType
  = Leq
  | Geq
  | Eq
  deriving (Show, Eq)

-- | State of the optimization solver
data OptimizationState = OptimizationState
  { osVariables :: !(M.Map Text Double)
  , osObjectiveValue :: !Double
  , osIterations :: !Int
  , osConverged :: !Bool
  } deriving (Show, Eq)

defOptimizationState :: M.Map Text Double -> OptimizationState
defOptimizationState vars = OptimizationState
  { osVariables = vars
  , osObjectiveValue = 0.0
  , osIterations = 0
  , osConverged = False
  }

evaluateObjective :: Objective -> M.Map Text Double -> Double
evaluateObjective !obj !vars
  | M.null vars = 0.0
  | otherwise =
    let coeffs = objCoefficients obj
        total = M.foldlWithKey (\acc k v -> acc + v * M.findWithDefault 0.0 k vars) 0.0 coeffs
    in total

checkConstraint :: Constraint -> M.Map Text Double -> Bool
checkConstraint !con !vars =
  let lhs = M.foldlWithKey (\acc k v -> acc + v * M.findWithDefault 0.0 k vars) 0.0 (conCoefficients con)
  in case conType con of
       Leq -> lhs <= conRHS con
       Geq -> lhs >= conRHS con
       Eq  -> abs (lhs - conRHS con) < 1e-10

optimize :: Objective -> [Constraint] -> M.Map Text Double -> OptimizationState
optimize !obj !constraints !initialVars
  | M.null initialVars = defOptimizationState M.empty
  | not (all (`checkConstraint` initialVars) constraints) =
    defOptimizationState initialVars
  | otherwise =
    let val = evaluateObjective obj initialVars
    in OptimizationState
         { osVariables = initialVars
         , osObjectiveValue = val
         , osIterations = 1
         , osConverged = True
         }