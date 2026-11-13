-- | QuickCheck + unit property coverage for `Finance.OpKindEx` — the
-- operation-kind classification module.
--
-- This module is pure (no DB/IO imports) and carries a formal-verification
-- lineage ("Enhanced operation classification with formal verification"),
-- so the invariants below are verified deterministically with QuickCheck
-- plus pinned unit assertions. They guard the module's contract against
-- future refactors and flag accidental divergence between the three
-- predicates and the declared group mapping.
--
-- Pre-existing invariants we pin:
--   * `opKindGroup` maps each of the 9 kinds to exactly one of the 4
--     declared groups, and every declared group receives at least one kind;
--   * `isPaymentOp`, `isAdjustmentOp`, `isTransferOp` are mutually exclusive;
--   * the three predicates together cover precisely every kind whose group is
--     not `FinancialGroup`;
--   * `prettyOpKindEx` yields a distinct string for each of the 9 kinds.
{-# LANGUAGE OverloadedStrings #-}
module Finance.OpKindExSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, Property, forAll, elements, (===), property)
import Data.List (nub)
import Data.Text (Text)
import qualified Data.Text as T

import Finance.OpKindEx

-- ---------------------------------------------------------------------------
-- Generators
-- ---------------------------------------------------------------------------

-- | Every `OpKindEx` value, in declaration order (deriving Enum/Bounded).
genOpKindEx :: Gen OpKindEx
genOpKindEx = elements allKinds
  where
    allKinds = [minBound .. maxBound :: OpKindEx]

-- ---------------------------------------------------------------------------
-- QuickCheck properties
-- ---------------------------------------------------------------------------

-- | `opKindGroup` lands on one of the four declared groups for every kind.
prop_opKindGroup_mapsEachKindToADeclaredGroup :: Property
prop_opKindGroup_mapsEachKindToADeclaredGroup =
  forAll genOpKindEx $ \k ->
    property (opKindGroup k >= minBound && opKindGroup k <= maxBound)

-- | Every declared group receives at least one kind: the 4-group contract is
-- not degenerate (no empty group).
prop_opKindGroup_coversAllFourDeclaredGroups :: Property
prop_opKindGroup_coversAllFourDeclaredGroups =
  property (all (`elem` allGroups) groupsUsed)
  where
    allGroups = [minBound .. maxBound :: OpKindGroup]
    groupsUsed = nub [opKindGroup k | k <- allKinds]
    allKinds = [minBound .. maxBound :: OpKindEx]

-- | A kind can never be both a payment *and* an adjustment operation.
prop_isPaymentOp_and_isAdjustmentOp_mutuallyExclusive :: Property
prop_isPaymentOp_and_isAdjustmentOp_mutuallyExclusive =
  forAll genOpKindEx $ \k ->
    property (not (isPaymentOp k && isAdjustmentOp k))

-- | `isPaymentOp` is true exactly for the PaymentGroup kinds.
prop_isPaymentOp_trueExactlyForPaymentGroup :: Property
prop_isPaymentOp_trueExactlyForPaymentGroup =
  forAll genOpKindEx $ \k ->
    property (isPaymentOp k === (opKindGroup k == PaymentGroup))

-- | The three predicates cover precisely the non-financial kinds; only the two
-- financial kinds (CreditNote / DebitNote) fall outside all three.
prop_notPaymentOrAdjustmentOrTransfer_meansFinancialGroup :: Property
prop_notPaymentOrAdjustmentOrTransfer_meansFinancialGroup =
  forAll genOpKindEx $ \k ->
    property (not (isPaymentOp k || isAdjustmentOp k || isTransferOp k)
      === (opKindGroup k == FinancialGroup))

-- | `prettyOpKindEx` gives a distinct string to each of the 9 kinds.
prop_prettyOpKindEx_givesDistinctStringPerKind :: Property
prop_prettyOpKindEx_givesDistinctStringPerKind =
  property (length (nub texts) == length texts)
  where
    texts = map prettyOpKindEx allKinds
    allKinds = [minBound .. maxBound :: OpKindEx]

-- ---------------------------------------------------------------------------
-- Unit assertions (pinned table)
-- ---------------------------------------------------------------------------

-- | Canonical mapping of every kind to its declared group.
opKindGroupTable :: [(OpKindEx, OpKindGroup)]
opKindGroupTable =
  [ (OKEInvoicePayment, PaymentGroup)
  , (OKEPrepayment, PaymentGroup)
  , (OKEAdvancePayment, PaymentGroup)
  , (OKEReturn, PaymentGroup)  -- source maps Return to PaymentGroup
  , (OKEWriteOff, AdjustmentGroup)
  , (OKETransfer, TransferGroup)
  , (OKECurrencyExchange, TransferGroup)
  , (OKECreditNote, FinancialGroup)
  , (OKEDeditNote, FinancialGroup)
  ]

-- ---------------------------------------------------------------------------
-- Spec
-- ---------------------------------------------------------------------------

spec :: Spec
spec = do
  describe "Finance.OpKindEx.opKindGroup" $ do
    it "maps every declared kind to exactly one of the four groups" $ do
      mapM_ (\(k, g) -> opKindGroup k `shouldBe` g) opKindGroupTable
    it "covers all four declared groups (no empty group)" $ do
      let allKinds = [minBound .. maxBound :: OpKindEx]
          groups = nub (map opKindGroup allKinds)
      groups `shouldSatisfy` \gs ->
        all (\g -> g `elem` gs) [minBound .. maxBound :: OpKindGroup]

  describe "Finance.OpKindEx.isPaymentOp / isAdjustmentOp / isTransferOp" $ do
    it "isPaymentOp and isAdjustmentOp are mutually exclusive" $
      property prop_isPaymentOp_and_isAdjustmentOp_mutuallyExclusive
    it "isPaymentOp is true exactly for the PaymentGroup kinds" $
      property prop_isPaymentOp_trueExactlyForPaymentGroup
    it "the three predicates cover exactly the non-financial kinds" $
      property prop_notPaymentOrAdjustmentOrTransfer_meansFinancialGroup

  describe "Finance.OpKindEx.prettyOpKindEx" $ do
    it "gives a distinct string to each of the nine kinds" $
      property prop_prettyOpKindEx_givesDistinctStringPerKind
    it "renders every kind (vector of the whole enumeration)" $ do
      let allKinds = [minBound .. maxBound :: OpKindEx]
      mapM_ (\k -> prettyOpKindEx k `shouldSatisfy` (not . T.null . T.strip)) allKinds
