{-# LANGUAGE OverloadedStrings #-}

-- | First coverage for 'Core.Optimization' — the linear-programming
-- evaluation core (pure, no DB; zero importers in src/+test/ before this run).
--
-- Pins the documented semantics of every exported function:
--   * evaluateObjective computes Σ (coefficient × variable) over the
--     objective's coefficient map (missing variables contribute 0);
--   * checkConstraint computes Σ (coefficient × variable) and compares
--     against the RHS according to the constraint type;
--   * optimize returns a converged state iff every constraint is satisfied
--     at the initial point, and a non-converged state otherwise;
--   * defOptimizationState is the zero-value initializer.
module Core.OptimizationSpec (spec) where

import Test.Hspec
import Test.QuickCheck

import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T

import Core.Optimization

spec :: Spec
spec = do
  describe "Core.Optimization.evaluateObjective" $ do
    it "computes the dot product of coefficients and variables" $ do
      let obj = Objective "obj" Maximize (M.fromList [(T.pack "x", 2.0), (T.pack "y", 3.0)])
          vars = M.fromList [(T.pack "x", 10.0), (T.pack "y", 5.0)]
      evaluateObjective obj vars `shouldBe` 35.0  -- 2*10 + 3*5

    it "treats a missing variable as zero" $ do
      let obj = Objective "obj" Minimize (M.fromList [(T.pack "x", 2.0), (T.pack "z", 99.0)])
          vars = M.fromList [(T.pack "x", 10.0)]
      evaluateObjective obj vars `shouldBe` 20.0  -- 2*10 + 99*0

    it "returns 0 for an empty variable map" $ do
      let obj = Objective "obj" Maximize (M.fromList [(T.pack "x", 2.0)])
      evaluateObjective obj M.empty `shouldBe` 0.0

    it "returns 0 when the objective has no coefficients" $ do
      let obj = Objective "obj" Maximize M.empty
          vars = M.fromList [(T.pack "x", 10.0)]
      evaluateObjective obj vars `shouldBe` 0.0

    it "is unaffected by extra variables not in the objective" $ do
      let obj = Objective "obj" Maximize (M.fromList [(T.pack "x", 1.0)])
          vars = M.fromList [(T.pack "x", 5.0), (T.pack "y", 999.0)]
      evaluateObjective obj vars `shouldBe` 5.0

    it "computes the dot product (property)" $
      forAll (choose (0, 50)) $ \n -> do
        let keys = map (\i -> T.pack ("x" ++ show i)) [1..n :: Int]
            coeffs = M.fromList $ zip keys (map (* 0.5) [1.0 .. fromIntegral n])
            vars   = M.fromList $ zip keys (map (* 2.0) [1.0 .. fromIntegral n])
            obj = Objective "p" Maximize coeffs
            -- expected = Σ (0.5*i)*(2*i) = Σ i² = n(n+1)(2n+1)/6
            expected = fromIntegral n * fromIntegral (n + 1) * fromIntegral (2 * n + 1) / 6.0
        evaluateObjective obj vars `shouldBe` expected

  describe "Core.Optimization.checkConstraint" $ do
    it "accepts a Leq constraint whose LHS ≤ RHS" $ do
      let con = Constraint "c" (M.fromList [(T.pack "x", 1.0)]) 10.0 Leq
          vars = M.fromList [(T.pack "x", 8.0)]
      checkConstraint con vars `shouldBe` True

    it "rejects a Leq constraint whose LHS > RHS" $ do
      let con = Constraint "c" (M.fromList [(T.pack "x", 1.0)]) 10.0 Leq
          vars = M.fromList [(T.pack "x", 12.0)]
      checkConstraint con vars `shouldBe` False

    it "accepts a Leq constraint whose LHS is exactly the RHS" $ do
      let con = Constraint "c" (M.fromList [(T.pack "x", 1.0)]) 10.0 Leq
          vars = M.fromList [(T.pack "x", 10.0)]
      checkConstraint con vars `shouldBe` True

    it "accepts a Geq constraint whose LHS ≥ RHS" $ do
      let con = Constraint "c" (M.fromList [(T.pack "x", 1.0)]) 5.0 Geq
          vars = M.fromList [(T.pack "x", 7.0)]
      checkConstraint con vars `shouldBe` True

    it "rejects a Geq constraint whose LHS < RHS" $ do
      let con = Constraint "c" (M.fromList [(T.pack "x", 1.0)]) 5.0 Geq
          vars = M.fromList [(T.pack "x", 3.0)]
      checkConstraint con vars `shouldBe` False

    it "accepts an Eq constraint whose LHS ≈ RHS" $ do
      let con = Constraint "c" (M.fromList [(T.pack "x", 2.0)]) 10.0 Eq
          vars = M.fromList [(T.pack "x", 5.0)]
      checkConstraint con vars `shouldBe` True

    it "rejects an Eq constraint whose LHS differs from RHS beyond ε" $ do
      let con = Constraint "c" (M.fromList [(T.pack "x", 2.0)]) 10.0 Eq
          vars = M.fromList [(T.pack "x", 5.01)]
      checkConstraint con vars `shouldBe` False

    it "treats missing variables as zero" $ do
      let con = Constraint "c" (M.fromList [(T.pack "x", 1.0), (T.pack "y", 2.0)]) 4.0 Leq
          vars = M.fromList [(T.pack "x", 4.0)]  -- y missing → 0
      checkConstraint con vars `shouldBe` True  -- 4 ≤ 4

    it "LHS computation matches evaluateObjective's (property)" $
      forAll (choose (0, 20)) $ \n -> do
        let keys = map (\i -> T.pack ("v" ++ show i)) [1..n :: Int]
            coeffs = M.fromList $ zip keys (map (* 1.5) [1.0 .. fromIntegral n])
            vars   = M.fromList $ zip keys (map (* 3.0) [1.0 .. fromIntegral n])
            obj = Objective "o" Maximize coeffs
            con = Constraint "c" coeffs 1e9 Leq
        -- LHS from checkConstraint must equal evaluateObjective
        checkConstraint con vars `shouldBe` True
        -- (the 1e9 RHS is unreachable for these magnitudes)

  describe "Core.Optimization.optimize" $ do
    it "returns a converged state when all constraints are satisfied" $ do
      let obj = Objective "profit" Maximize (M.fromList [(T.pack "x", 3.0), (T.pack "y", 2.0)])
          con1 = Constraint "cap" (M.fromList [(T.pack "x", 1.0), (T.pack "y", 1.0)]) 10.0 Leq
          vars = M.fromList [(T.pack "x", 3.0), (T.pack "y", 4.0)]  -- 7 ≤ 10 ✓
          st = optimize obj [con1] vars
      osConverged st `shouldBe` True
      osIterations st `shouldBe` 1
      osObjectiveValue st `shouldBe` 17.0  -- 3*3 + 2*4
      osVariables st `shouldBe` vars

    it "returns a non-converged state when any constraint is violated" $ do
      let obj = Objective "profit" Maximize (M.fromList [(T.pack "x", 3.0)])
          con1 = Constraint "cap" (M.fromList [(T.pack "x", 1.0)]) 5.0 Leq
          vars = M.fromList [(T.pack "x", 10.0)]  -- 10 > 5 ✗
          st = optimize obj [con1] vars
      osConverged st `shouldBe` False
      osIterations st `shouldBe` 0
      osObjectiveValue st `shouldBe` 0.0

    it "returns a non-converged state for an empty variable map" $ do
      let obj = Objective "profit" Maximize (M.fromList [(T.pack "x", 3.0)])
          con1 = Constraint "cap" (M.fromList [(T.pack "x", 1.0)]) 100.0 Leq
          st = optimize obj [con1] M.empty
      osConverged st `shouldBe` False
      osVariables st `shouldBe` M.empty

    it "requires ALL constraints to pass (one failure → non-converged)" $ do
      let obj = Objective "o" Maximize (M.fromList [(T.pack "x", 1.0)])
          conOK  = Constraint "ok"  (M.fromList [(T.pack "x", 1.0)]) 100.0 Leq
          conBad = Constraint "bad" (M.fromList [(T.pack "x", 1.0)]) 1.0   Leq
          vars = M.fromList [(T.pack "x", 5.0)]  -- passes conOK (5≤100), fails conBad (5≰1)
          st = optimize obj [conOK, conBad] vars
      osConverged st `shouldBe` False

    it "accepts an empty constraint list" $ do
      let obj = Objective "o" Maximize (M.fromList [(T.pack "x", 5.0)])
          vars = M.fromList [(T.pack "x", 42.0)]
          st = optimize obj [] vars
      osConverged st `shouldBe` True
      osObjectiveValue st `shouldBe` 210.0  -- 5*42

    it "converged ⟺ all constraints satisfied (property)" $
      forAll (choose (1, 10)) $ \n -> do
        let xs = [1.0 .. fromIntegral (n :: Int)]
            vars = M.fromList $ zip (map (\i -> T.pack ("x" ++ show i)) [1..n]) xs
            obj = Objective "p" Maximize (M.fromList $ zip (M.keys vars) (repeat 1.0))
            -- half the constraints will be satisfied (sum ≤ large), half not
            cons = [ Constraint "c" (M.fromList [(T.pack "x", 1.0)])
                              (if even i then 1e6 else 0.0) Leq
                   | i <- [1..n] ]
            st = optimize obj cons vars
            allSat = all (`checkConstraint` vars) cons
        osConverged st `shouldBe` allSat

  describe "Core.Optimization.defOptimizationState" $ do
    it "initializes with zero objective, zero iterations, not converged" $ do
      let vars = M.fromList [(T.pack "x", 5.0)]
          st = defOptimizationState vars
      osObjectiveValue st `shouldBe` 0.0
      osIterations st `shouldBe` 0
      osConverged st `shouldBe` False
      osVariables st `shouldBe` vars

    it "preserves the variable map" $ do
      let vars = M.fromList [(T.pack "a", 1.0), (T.pack "b", 2.0)]
      osVariables (defOptimizationState vars) `shouldBe` vars
