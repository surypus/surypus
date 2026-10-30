-- | Unit and property-based tests for Finance.Account (chart of accounts).
-- First coverage for Finance.Account: account nature derivation, account code
-- validation, and account completion predicates.
--
-- Finance.Account is pure and has no production importers, so these tests are
-- deterministic: they need no database, no fixtures and no I/O.
{-# LANGUAGE OverloadedStrings #-}

module Finance.AccountSpec (spec) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)

import Finance.Account

import Test.Hspec
import Test.QuickCheck (elements, forAll, Gen, Property, property)

-- | Smart constructor for an account with a fixed code and name.
mkAccount :: Day -> Int64 -> AccountCode -> AccountName -> AccountClass -> Account
mkAccount created aid code name cls =
  createAccount created (AccountId aid) code name cls

-- | A few representative valid account codes (digits only).
validCodes :: [String]
validCodes = ["01", "10", "50", "60", "80", "90", "2025", "44", "55", "70"]

-- | Property: accountNature is always derivable from accountClass.
prop_natureDerivation :: Property
prop_natureDerivation =
  forAll (elements [minBound .. maxBound] :: Gen AccountClass) $ \cls ->
    let acc =
          mkAccount (fromGregorian 2026 10 20) 1 (AccountCode "1010") (AccountName "Equity") cls
        expect =
          case cls of
            AssetClass     -> DebitNature
            LiabilityClass -> CreditNature
            EquityClass    -> CreditNature
            RevenueClass   -> CreditNature
            ExpenseClass   -> DebitNature
    in property (accountNature acc == expect)

-- | Property: account code validation accepts every digit-only code.
prop_validCodeAccepted :: Property
prop_validCodeAccepted =
  forAll (elements validCodes) $ \c ->
    property (validateAccountCode (AccountCode (T.pack c)) == Just (AccountCode (T.pack c)))

-- | Property: account code validation rejects codes containing non-digits.
prop_invalidCodeRejected :: Property
prop_invalidCodeRejected =
  forAll (elements invalidCodes) $ \c ->
    property (validateAccountCode (AccountCode (T.pack c)) == Nothing)

invalidCodes :: [String]
invalidCodes = ["", "A101", " 101", "1a", "1 01", "1-01"]

-- | Account completeness and identity predicates (pure data access).
spec :: Spec
spec =
  describe "Finance.Account" $ do
    describe "accountClass -> accountNature" $ do
      it "assigns DebitNature to AssetClass" $ do
        let acc =
              mkAccount (fromGregorian 2026 10 20) 10 (AccountCode "01") (AccountName "PPH") AssetClass
         in accountNature acc `shouldBe` DebitNature
      it "assigns DebitNature to ExpenseClass" $ do
        let acc =
              mkAccount (fromGregorian 2026 10 20) 11 (AccountCode "20") (AccountName "Expenses") ExpenseClass
         in accountNature acc `shouldBe` DebitNature
      it "assigns CreditNature to LiabilityClass" $ do
        let acc =
              mkAccount (fromGregorian 2026 10 20) 20 (AccountCode "60") (AccountName "Equity") LiabilityClass
         in accountNature acc `shouldBe` CreditNature
      it "assigns CreditNature to EquityClass" $ do
        let acc =
              mkAccount (fromGregorian 2026 10 20) 21 (AccountCode "80") (AccountName "Equity") EquityClass
         in accountNature acc `shouldBe` CreditNature
      it "assigns CreditNature to RevenueClass" $ do
        let acc =
              mkAccount (fromGregorian 2026 10 20) 22 (AccountCode "90") (AccountName "Revenue") RevenueClass
         in accountNature acc `shouldBe` CreditNature
      it "property: every class maps to the documented nature" $
        property prop_natureDerivation

    describe "validateAccountCode" $ do
      it "accepts an existing valid code" $ do
        validateAccountCode (AccountCode "1010") `shouldBe` Just (AccountCode "1010")
      it "property: every digit-only code is accepted" $
        property prop_validCodeAccepted
      it "rejects a code with a letter" $ do
        validateAccountCode (AccountCode "1a") `shouldBe` Nothing
      it "rejects a code with a space" $ do
        validateAccountCode (AccountCode " 101") `shouldBe` Nothing
      it "rejects an empty code" $ do
        validateAccountCode (AccountCode "") `shouldBe` Nothing
      it "property: every code containing a non-digit is rejected" $
        property prop_invalidCodeRejected

    describe "isAssetAccount / isLiabilityAccount" $ do
      it "isAssetAccount is true only for AssetClass" $ do
        let asset =
              mkAccount (fromGregorian 2026 10 20) 30 (AccountCode "01") (AccountName "PPH") AssetClass
            other =
              mkAccount (fromGregorian 2026 10 20) 31 (AccountCode "60") (AccountName "Equity") LiabilityClass
        isAssetAccount asset `shouldBe` True
        isAssetAccount other `shouldBe` False
      it "isLiabilityAccount mirrors LiabilityClass" $ do
        let liab =
              mkAccount (fromGregorian 2026 10 20) 40 (AccountCode "60") (AccountName "Loans") LiabilityClass
            other =
              mkAccount (fromGregorian 2026 10 20) 41 (AccountCode "30") (AccountName "Stock") ExpenseClass
        isLiabilityAccount liab `shouldBe` True
        isLiabilityAccount other `shouldBe` False

    describe "createAccount / isActive" $ do
      it "creates an account with isActive True" $ do
        let acc = mkAccount (fromGregorian 2026 10 20) 50 (AccountCode "50") (AccountName "Cash") AssetClass
         in isActive acc `shouldBe` True
      it "preserves the account code verbatim" $ do
        let acc = mkAccount (fromGregorian 2026 10 20) 51 (AccountCode "0050") (AccountName "Cash") AssetClass
         in accountCode acc `shouldBe` AccountCode "0050"
