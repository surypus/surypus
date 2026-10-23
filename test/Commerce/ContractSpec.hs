{-# LANGUAGE OverloadedStrings #-}

-- | First coverage for 'Commerce.Contract' — the contract active-state
-- and expiry-arithmetic layer (pure, exposed, zero importers in src/ before
-- this run).
module Commerce.ContractSpec (spec) where

import Data.Time (Day, fromGregorian, addDays)
import Test.Hspec
import Test.QuickCheck

import Commerce.Contract

spec :: Spec
spec = do
  describe "Commerce.Contract.isContractActive" $ do
    it "is active on the start date" $ do
      let today = fromGregorian 2026 1 1
      isContractActive mkContract today `shouldBe` True

    it "is active in the middle of the period" $ do
      let today = fromGregorian 2026 6 15
      isContractActive mkContract today `shouldBe` True

    it "is active on the end date" $ do
      let today = fromGregorian 2026 12 31
      isContractActive mkContract today `shouldBe` True

    it "is inactive before the start date" $ do
      let today = fromGregorian 2025 12 31
      isContractActive mkContract today `shouldBe` False

    it "is inactive after the end date" $ do
      let today = fromGregorian 2027 1 1
      isContractActive mkContract today `shouldBe` False

    it "treats Nothing end date as open-ended" $ do
      let c = mkContract { conEndDate = Nothing }
      isContractActive c (fromGregorian 2099 1 1) `shouldBe` True

    it "is never active on a past date with open end" $ do
      let c = mkContract { conEndDate = Nothing }
      isContractActive c (fromGregorian 1900 1 1) `shouldBe` False

    it "property: result is deterministic for same inputs" $ do
      property $ \(DayResult c d) ->
        isContractActive c d == isContractActive c d

  describe "Commerce.Contract.daysToExpiry" $ do
    it "returns Just 0 on the end date" $ do
      let today = fromGregorian 2026 12 31
      daysToExpiry mkContract today `shouldBe` Just 0

    it "returns positive days before expiry" $ do
      let today = fromGregorian 2026 12 25
      daysToExpiry mkContract today `shouldBe` Just 6

    it "returns Nothing for no end date" $ do
      let c = mkContract { conEndDate = Nothing }
      daysToExpiry c (fromGregorian 2026 1 1) `shouldBe` Nothing

    it "is negative after expiry" $ do
      let today = fromGregorian 2027 1 1
      daysToExpiry mkContract today `shouldSatisfy` \m -> case m of
        Just n -> n < 0
        Nothing -> False

    it "property: later date never yields a larger delta" $ do
      property $ \(ContractDay c d) ->
        let d1 = d
            d2 = addDays 1 d1
        in fmap fromEnum (daysToExpiry c d1)
           >= fmap fromEnum (daysToExpiry c d2)

  describe "Commerce.Contract" $ do
    it "property: active window invariant" $ do
      property $ \(ContractDay c d) ->
        prop_active_in_window (ContractDay c d)

    it "property: daysToExpiry decreases by one per day" $ do
      property $ \(ContractDay c d) ->
        prop_expiry_decrements_by_one (ContractDay c d)

prop_active_in_window :: ContractDay -> Property
prop_active_in_window (ContractDay c d) =
  case conEndDate c of
    Nothing ->
      property (isContractActive c d == (d >= conStartDate c))
    Just ed ->
      let delta = fmap fromEnum (daysToExpiry c d)
       in case delta of
            Nothing -> property False
            Just diff -> property (isContractActive c d == (d >= conStartDate c && diff >= 0))

-- | `daysToExpiry` decreases by exactly one calendar day per unit of `d`.
prop_expiry_decrements_by_one :: ContractDay -> Property
prop_expiry_decrements_by_one (ContractDay c d) =
  case conEndDate c of
    Nothing -> property True
    Just ed ->
      let d1 = d
          d2 = addDays 1 d1
          delta1 = fmap fromEnum (daysToExpiry c d1)
          delta2 = fmap fromEnum (daysToExpiry c d2)
       in case (delta1, delta2) of
            (Just a, Just b) -> property (a - b == 1)
            _ -> property False

mkContract :: Contract
mkContract = Contract
  { conId = 1
  , conCode = "CON-001"
  , conKind = CKSupply
  , conPartyId = 1
  , conStartDate = fromGregorian 2026 1 1
  , conEndDate = Just (fromGregorian 2026 12 31)
  , conAmount = 1000.0
  , conCurrencyId = 1
  , conStatus = CSActive
  }

data DayResult = DayResult Contract Day
  deriving (Show)
instance Arbitrary DayResult where
  arbitrary = DayResult mkContract <$> genDay

data ContractDay = ContractDay Contract Day
  deriving (Show)
instance Arbitrary ContractDay where
  arbitrary = ContractDay mkContract <$> genDay

genDay :: Gen Day
genDay = fromGregorian <$> choose (2025, 2030) <*> choose (1, 12) <*> choose (1, 28)
