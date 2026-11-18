{-# LANGUAGE OverloadedStrings #-}

-- | QuickCheck + unit property coverage for `Finance.AccPlan`
--
-- `Finance.AccPlan` models an accounting-plan record together with its
-- smart constructor (`mkNonNeg`) and lifecycle helpers
-- (`createAccPlan` / `activateAccPlan` / `deactivateAccPlan` /
-- `isActivePlan` / `prettyAccPlan`).
--
-- Pinned invariants:
--   * `mkNonNeg` accepts every non-negative value and rejects negatives
--   * the accepted wrapper round-trips through `unNonNeg`
--   * `createAccPlan` applies the documented defaults
--     (no parent, active, created today, never updated)
--   * activate/deactivate toggle `apIsActive` and stamp `apUpdatedAt`
--   * `prettyAccPlan` always carries the code and name, and its
--     status suffix agrees with `apIsActive`
--
-- Pure logic module (no DB/IO); behaviour-only spec, no production change.
module Finance.AccPlanSpec (spec) where

import qualified Data.Text as T
import Data.Time.Calendar (Day, fromGregorian)
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, choose, forAll, elements)
import Test.QuickCheck.Property ((===))

import Finance.AccPlan

-- | Deterministic day generator (bounds keep the day valid).
genDay :: Gen Day
genDay = do
  y <- choose (2000, 2030)
  m <- choose (1, 12)
  d <- choose (1, 28)
  pure $ fromGregorian y m d

-- | A plan built through `createAccPlan` with generated ids/name/day.
genPlan :: Gen AccPlan
genPlan = do
  day <- genDay
  pure $ createAccPlan (AccPlanId 1) (PlanCode "AP-001") (PlanName "Test plan") day

spec :: Spec
spec = do
  describe "Finance.AccPlan.mkNonNeg" $ do
    it "accepts zero and returns the value verbatim" $
      mkNonNeg 0 `shouldBe` Right (NonNeg 0)
    it "rejects a negative value" $
      mkNonNeg (-0.01) `shouldSatisfy` isLeft
    prop "accepts every non-negative value"
         (forAll (choose (0, 1000000)) $ \v ->
            mkNonNeg v === Right (NonNeg v))
    prop "rejects every negative value"
         (forAll (choose (-1000000, -0.000001)) $ \v ->
            mkNonNeg v `shouldSatisfy` isLeft)
    prop "unNonNeg is a left inverse on accepted values"
         (forAll (choose (0, 1000000)) $ \v ->
            either (const Nothing) (Just . unNonNeg) (mkNonNeg v) === Just v)

  describe "Finance.AccPlan.createAccPlan" $ do
    it "applies the documented defaults" $ do
      let day = fromGregorian 2024 3 15
          p = createAccPlan (AccPlanId 7) (PlanCode "AP-007") (PlanName "Main") day
      apId p `shouldBe` AccPlanId 7
      apCode p `shouldBe` PlanCode "AP-007"
      apName p `shouldBe` PlanName "Main"
      apParentId p `shouldBe` Nothing
      apIsActive p `shouldBe` True
      apCreatedAt p `shouldBe` day
      apUpdatedAt p `shouldBe` Nothing
    prop "every created plan starts active, parentless and unmodified"
         (forAll genPlan $ \p ->
            apIsActive p && apParentId p == Nothing && apUpdatedAt p == Nothing)

  describe "Finance.AccPlan lifecycle" $ do
    it "deactivateAccPlan clears the active flag and stamps the update date" $ do
      let p = deactivateAccPlan (createAccPlan (AccPlanId 1) (PlanCode "A") (PlanName "B") (fromGregorian 2024 1 1))
      isActivePlan p `shouldBe` False
      apUpdatedAt p `shouldBe` Just (fromGregorian 2024 1 1)
    it "activateAccPlan restores the active flag" $ do
      let p = activateAccPlan (deactivateAccPlan (createAccPlan (AccPlanId 1) (PlanCode "A") (PlanName "B") (fromGregorian 2024 1 1)))
      isActivePlan p `shouldBe` True
    prop "activate/deactivate agree with isActivePlan"
         (forAll genPlan $ \p ->
            isActivePlan (activateAccPlan p) && not (isActivePlan (deactivateAccPlan p)))
    prop "activate after deactivate restores the fields"
         (forAll genPlan $ \p ->
            let p' = activateAccPlan (deactivateAccPlan p)
            in apIsActive p' && apUpdatedAt p' == Just (fromGregorian 2024 1 1))

  describe "Finance.AccPlan.prettyAccPlan" $ do
    it "renders code, name and the active marker" $
      prettyAccPlan (createAccPlan (AccPlanId 1) (PlanCode "AP-1") (PlanName "Main") (fromGregorian 2024 1 1))
        `shouldBe` "AP-1 - Main (Active)"
    it "renders the inactive marker" $
      prettyAccPlan (deactivateAccPlan (createAccPlan (AccPlanId 1) (PlanCode "AP-1") (PlanName "Main") (fromGregorian 2024 1 1)))
        `shouldBe` "AP-1 - Main (Inactive)"
    prop "always contains the plan code and name"
         (forAll genPlan $ \p ->
            T.isInfixOf (unPlanCode (apCode p)) (prettyAccPlan p)
              && T.isInfixOf (unPlanName (apName p)) (prettyAccPlan p))
    prop "status suffix matches the active flag"
         (forAll genPlan $ \p ->
            forAll (elements [True, False]) $ \active ->
              let p' = if active then activateAccPlan p else deactivateAccPlan p
                  expected = if active then " (Active)" else " (Inactive)"
              in T.isInfixOf expected (prettyAccPlan p'))

-- | Local helper: recognise a rejected 'Either'.
isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft _ = False
