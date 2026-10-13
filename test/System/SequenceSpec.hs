{-# LANGUAGE OverloadedStrings #-}

-- | Unit and property-based tests for System.Sequence.
-- Tests the Sequence type and nextNumber function including
-- prefix/suffix concatenation and increment behaviour.
module System.SequenceSpec (spec) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import System.Sequence (Sequence (..), nextNumber)
import Test.Hspec
import Test.QuickCheck

-- | Build a sequence with sensible defaults.
mkSequence :: Int -> Text -> Sequence
mkSequence lastVal suffix =
  Sequence
    { seqId = 1,
      seqName = "test-sequence",
      seqPrefix = "DOC-",
      seqSuffix = suffix,
      seqLastNum = lastVal,
      seqStep = 1,
      seqFlags = 0
    }

spec :: Spec
spec = do
  describe "nextNumber" nextNumberSpec
  describe "Prefix and suffix" prefixSuffixSpec
  describe "Step semantics" stepSpec
  describe "Properties" propertiesSpec

-- ============================================================================
-- nextNumber basic behaviour
-- ============================================================================

nextNumberSpec :: Spec
nextNumberSpec = do
  it "increments the last number by 1" $
    nextNumber (mkSequence 0 "") `shouldBe` "DOC-1"

  it "increments from an arbitrary starting value" $
    nextNumber (mkSequence 42 "") `shouldBe` "DOC-43"

  it "handles zero" $
    nextNumber (mkSequence 0 "") `shouldBe` "DOC-1"

  it "handles large numbers" $
    nextNumber (mkSequence 999999 "") `shouldBe` "DOC-1000000"

  it "returns Text type" $
    nextNumber (mkSequence 0 "") `shouldBe` ("DOC-1" :: Text)

-- ============================================================================
-- Prefix and suffix handling
-- ============================================================================

prefixSuffixSpec :: Spec
prefixSuffixSpec = do
  it "prepends prefix to the result" $
    nextNumber (mkSequence 0 "A") `shouldBe` "DOC-1A"

  it "appends suffix to the result" $
    nextNumber (mkSequence 0 "-2025") `shouldBe` "DOC-1-2025"

  it "handles empty prefix" $ do
    let s = (mkSequence 5 "") { seqPrefix = "" }
    nextNumber s `shouldBe` "6"

  it "handles empty suffix" $ do
    let s = (mkSequence 5 "") { seqSuffix = "" }
    nextNumber s `shouldBe` "DOC-6"

  it "handles both empty prefix and suffix" $ do
    let s = (mkSequence 5 "") { seqPrefix = "", seqSuffix = "" }
    nextNumber s `shouldBe` "6"

  it "handles multi-character prefix" $ do
    let s = (mkSequence 0 "") { seqPrefix = "ORDER-" }
    nextNumber s `shouldBe` "ORDER-1"

  it "handles multi-character suffix" $ do
    let s = (mkSequence 0 "") { seqSuffix = "-DRAFT" }
    nextNumber s `shouldBe` "DOC-1-DRAFT"

-- ============================================================================
-- Step semantics
-- ============================================================================

-- | nextNumber must honour the sequence's configured 'seqStep' — the field
-- existed but was silently ignored (always +1), so a sequence configured
-- with step 5 produced 1, 2, 3… instead of 5, 10, 15….
stepSpec :: Spec
stepSpec = do
  it "increments by the configured step" $ do
    let s = (mkSequence 0 "") { seqStep = 5 }
    nextNumber s `shouldBe` "DOC-5"

  it "increments by a large step from a nonzero base" $ do
    let s = (mkSequence 42 "") { seqStep = 10 }
    nextNumber s `shouldBe` "DOC-52"

  it "honours a negative step" $ do
    let s = (mkSequence 10 "") { seqStep = -3 }
    nextNumber s `shouldBe` "DOC-7"

  it "zero step yields no movement" $ do
    let s = (mkSequence 7 "") { seqStep = 0 }
    nextNumber s `shouldBe` "DOC-7"

  it "step applies before prefix/suffix concatenation" $ do
    let s = (mkSequence 5 "-2025") { seqStep = 3 }
    nextNumber s `shouldBe` "DOC-8-2025"

  it "step of 1 is the default increment" $ do
    let s = (mkSequence 99 "") { seqStep = 1 }
    nextNumber s `shouldBe` "DOC-100"

-- ============================================================================
-- Property-based tests
-- ============================================================================

propertiesSpec :: Spec
propertiesSpec = do
  it "always increments by 1" $ property prop_incrementsByOne
  it "result always starts with prefix" $ property prop_startsWithPrefix
  it "result always ends with suffix" $ property prop_endsWithSuffix
  it "result length >= prefix + suffix + 1" $ property prop_minLength
  it "numeric part equals last number + step" $ property prop_numericEqualsLastPlusStep

-- | Property: nextNumber always increments by 1
prop_incrementsByOne :: Property
prop_incrementsByOne =
  forAll (choose (0, 100000 :: Int)) $ \n ->
    let s = mkSequence n ""
        result = nextNumber s
        numPart = T.drop (T.length $ seqPrefix s) result
        numericValue = read (T.unpack numPart) :: Int
    in numericValue == n + 1

-- | Property: result always starts with the prefix
prop_startsWithPrefix :: Property
prop_startsWithPrefix =
  forAll (choose (0, 10000 :: Int)) $ \n ->
    forAll (elements ["", "X", "-2025", "#"]) $ \suf ->
      let s = mkSequence n suf
      in T.isPrefixOf (seqPrefix s) (nextNumber s)

-- | Property: result always ends with the suffix
prop_endsWithSuffix :: Property
prop_endsWithSuffix =
  forAll (choose (0, 10000 :: Int)) $ \n ->
    forAll (elements ["", "X", "-2025", "#"]) $ \suf ->
      let s = mkSequence n suf
      in T.isSuffixOf (seqSuffix s) (nextNumber s)

-- | Property: result length is at least prefix + suffix + 1
prop_minLength :: Property
prop_minLength =
  forAll (choose (0, 10000 :: Int)) $ \n ->
    forAll (elements ["", "X", "-2025", "#"]) $ \suf ->
      let s = mkSequence n suf
          result = nextNumber s
      in T.length result >= T.length (seqPrefix s) + T.length (seqSuffix s) + 1

-- | Property: the numeric part equals last number + configured step,
-- across negative, zero and positive steps.
prop_numericEqualsLastPlusStep :: Property
prop_numericEqualsLastPlusStep =
  forAll (choose (0, 100000 :: Int)) $ \n ->
    forAll (elements ([-5, -1, 0, 1, 2, 3, 5, 100] :: [Int])) $ \st ->
      let s = (mkSequence n "") { seqStep = st }
          result = nextNumber s
          numPart = T.drop (T.length $ seqPrefix s) result
          numericValue = read (T.unpack numPart) :: Int
      in numericValue == n + st
