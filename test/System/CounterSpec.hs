{-# LANGUAGE OverloadedStrings #-}

-- | Unit and property-based tests for System.Counter.
-- Tests the Counter type and nextCounterValue function including
-- padding logic, prefix/suffix concatenation, and increment behaviour.
module System.CounterSpec (spec) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import System.Counter (Counter (..), nextCounterValue)
import Test.Hspec
import Test.QuickCheck

-- | Build a counter with sensible defaults.
mkCounter :: Int -> Text -> Counter
mkCounter lastVal suffix =
  Counter
    { cntId = 1,
      cntName = "test-counter",
      cntPrefix = "INV-",
      cntSuffix = suffix,
      cntPadding = 6,
      cntLastValue = lastVal
    }

spec :: Spec
spec = do
  describe "nextCounterValue" nextCounterValueSpec
  describe "Padding behaviour" paddingSpec
  describe "Prefix and suffix" prefixSuffixSpec
  describe "Properties" propertiesSpec

propertiesSpec :: Spec
propertiesSpec = do
  it "always increments by 1 (or exceeds padding)" $ property prop_incrementsByOne
  it "result always starts with prefix" $ property prop_startsWithPrefix
  it "result always ends with suffix" $ property prop_endsWithSuffix
  it "result length >= prefix + padding + suffix" $ property prop_minLength

-- ============================================================================
-- nextCounterValue basic behaviour
-- ============================================================================

nextCounterValueSpec :: Spec
nextCounterValueSpec = do
  it "increments the counter value by 1" $
    nextCounterValue (mkCounter 0 "") `shouldBe` "INV-000001"

  it "formats single-digit numbers with leading zeros" $
    nextCounterValue (mkCounter 5 "") `shouldBe` "INV-000006"

  it "formats numbers at padding boundary correctly" $
    nextCounterValue (mkCounter 99998 "") `shouldBe` "INV-099999"

  it "handles numbers exceeding padding (no truncation)" $
    nextCounterValue (mkCounter 999999 "") `shouldBe` "INV-1000000"

  it "returns Text type" $
    nextCounterValue (mkCounter 0 "") `shouldBe` ("INV-000001" :: Text)

-- ============================================================================
-- Padding behaviour
-- ============================================================================

paddingSpec :: Spec
paddingSpec = do
  it "pads with leading zeros to reach padding width" $ do
    let c = (mkCounter 42 "") { cntPadding = 4 }
    nextCounterValue c `shouldBe` "INV-0043"

  it "does not pad when number already exceeds padding width" $ do
    let c = (mkCounter 12345 "") { cntPadding = 3 }
    nextCounterValue c `shouldBe` "INV-12346"

  it "handles padding = 1 (minimal padding)" $ do
    let c = (mkCounter 7 "") { cntPadding = 1 }
    nextCounterValue c `shouldBe` "INV-8"

  it "handles zero padding (no padding)" $ do
    let c = (mkCounter 99 "") { cntPadding = 0 }
    nextCounterValue c `shouldBe` "INV-100"

  it "handles padding = number length exactly" $ do
    let c = (mkCounter 999 "") { cntPadding = 4 }
    nextCounterValue c `shouldBe` "INV-1000"

-- ============================================================================
-- Prefix and suffix handling
-- ============================================================================

prefixSuffixSpec :: Spec
prefixSuffixSpec = do
  it "prepends prefix to the result" $
    nextCounterValue (mkCounter 0 "A") `shouldBe` "INV-000001A"

  it "appends suffix to the result" $
    nextCounterValue (mkCounter 0 "-2025") `shouldBe` "INV-000001-2025"

  it "handles empty prefix" $ do
    let c = (mkCounter 5 "") { cntPrefix = "" }
    nextCounterValue c `shouldBe` "000006"

  it "handles empty suffix" $ do
    let c = (mkCounter 5 "") { cntSuffix = "" }
    nextCounterValue c `shouldBe` "INV-000006"

  it "handles both empty prefix and suffix" $ do
    let c = (mkCounter 5 "") { cntPrefix = "", cntSuffix = "" }
    nextCounterValue c `shouldBe` "000006"

  it "handles multi-character prefix" $ do
    let c = (mkCounter 0 "") { cntPrefix = "ORDER-" }
    nextCounterValue c `shouldBe` "ORDER-000001"

  it "handles multi-character suffix" $ do
    let c = (mkCounter 0 "") { cntSuffix = "-DRAFT" }
    nextCounterValue c `shouldBe` "INV-000001-DRAFT"

-- ============================================================================
-- Property-based tests
-- ============================================================================

-- | Property: nextCounterValue always increments by 1
prop_incrementsByOne :: Property
prop_incrementsByOne =
  forAll (choose (0, 100000 :: Int)) $ \n ->
    let c = mkCounter n ""
        result = nextCounterValue c
        -- Extract the numeric part between prefix and suffix
        numPart = T.drop (T.length $ cntPrefix c) result
        numericValue = read (T.unpack numPart) :: Int
    in numericValue == n + 1

-- | Property: result always starts with the prefix
prop_startsWithPrefix :: Property
prop_startsWithPrefix =
  forAll (choose (0, 10000 :: Int)) $ \n ->
    forAll (elements ["", "X", "-2025", "#"]) $ \suf ->
      let c = mkCounter n suf
      in T.isPrefixOf (cntPrefix c) (nextCounterValue c)

-- | Property: result always ends with the suffix
prop_endsWithSuffix :: Property
prop_endsWithSuffix =
  forAll (choose (0, 10000 :: Int)) $ \n ->
    forAll (elements ["", "X", "-2025", "#"]) $ \suf ->
      let c = mkCounter n suf
      in T.isSuffixOf (cntSuffix c) (nextCounterValue c)

-- | Property: result length is at least prefix + padding + suffix length
prop_minLength :: Property
prop_minLength =
  forAll (choose (0, 10000 :: Int)) $ \n ->
    forAll (elements ["", "X", "-2025", "#"]) $ \suf ->
      let c = mkCounter n suf
          result = nextCounterValue c
      in T.length result >= T.length (cntPrefix c) + cntPadding c + T.length (cntSuffix c)
