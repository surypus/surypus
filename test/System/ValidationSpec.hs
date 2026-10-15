{-# LANGUAGE OverloadedStrings, LambdaCase, ScopedTypeVariables #-}

module System.ValidationSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import Data.Text (Text)
import qualified Data.Text as T
import System.Validation

instance Arbitrary Text where
  arbitrary = T.pack <$> arbitrary

newtype ValidEmail = ValidEmail Text
  deriving (Show)

instance Arbitrary ValidEmail where
  arbitrary = do
    user <- listOf1 (elements (['a'..'z'] ++ ['0'..'9']))
    domain <- listOf1 (elements (['a'..'z'] ++ ['0'..'9']))
    tld <- listOf1 (elements (['a'..'z']))
    return $ ValidEmail (T.pack (user ++ "@" ++ domain ++ "." ++ tld))

newtype NonBlankText = NonBlankText Text
  deriving (Show)

instance Arbitrary NonBlankText where
  arbitrary = do
    cs <- listOf1 (elements (['a'..'z'] ++ ['A'..'Z'] ++ ['0'..'9']))
    return $ NonBlankText (T.pack cs)

spec :: Spec
spec = do
  describe "validateRequired" $ do
    it "accepts a present value" $
      validateRequired "name" (Just "Alice") `shouldBe` Right "Alice"
    it "rejects a missing value" $
      (validateRequired "name" Nothing :: Either ValidationError Text)
        `shouldBe` Left (RequiredFieldMissing "name")

  describe "validateEmail" $ do
    it "accepts a valid email" $
      validateEmail "user@example.com" `shouldBe` Right "user@example.com"
    it "rejects an email without @" $
      validateEmail "userexample.com" `shouldSatisfy` isLeft
    it "rejects an email without ." $
      validateEmail "user@examplecom" `shouldSatisfy` isLeft
    it "rejects an empty email" $
      validateEmail "" `shouldSatisfy` isLeft
    it "rejects whitespace-only email" $
      validateEmail "   " `shouldSatisfy` isLeft

  describe "validateRange" $ do
    it "accepts a value inside the range" $
      validateRange "age" 25 (0, 150) `shouldBe` Right (25 :: Int)
    it "accepts the lower boundary" $
      validateRange "age" 0 (0, 150) `shouldBe` Right (0 :: Int)
    it "accepts the upper boundary" $
      validateRange "age" 150 (0, 150) `shouldBe` Right (150 :: Int)
    it "rejects a value below the range" $
      validateRange "age" (-1) (0, 150) `shouldSatisfy` isLeft
    it "rejects a value above the range" $
      validateRange "age" 151 (0, 150) `shouldSatisfy` isLeft
    it "works with Double" $
      validateRange "score" 3.5 (0.0, 5.0) `shouldBe` Right (3.5 :: Double)

  describe "validateNonEmpty" $ do
    it "accepts non-empty text" $
      validateNonEmpty "hello" `shouldBe` Right "hello"
    it "rejects empty text" $
      validateNonEmpty "" `shouldSatisfy` isLeft
    it "rejects whitespace-only text" $
      validateNonEmpty "   " `shouldSatisfy` isLeft
    it "accepts text with leading/trailing whitespace" $
      validateNonEmpty "  hello  " `shouldBe` Right "  hello  "

  describe "validateAll" $ do
    it "returns all successes when all validations pass" $
      validateAll [validateRequired "name" (Just "Alice"), validateEmail "a@b.com"]
        `shouldBe` Right ["Alice", "a@b.com"]
    it "collects all errors when some validations fail" $
      validateAll [validateRequired "name" Nothing, validateEmail "invalid"]
        `shouldSatisfy` \case
          Left errs -> length errs == 2
          Right _ -> False
    it "returns all errors when all validations fail" $
      validateAll [validateRequired "name" Nothing, validateEmail "bad", validateNonEmpty ""]
        `shouldSatisfy` \case
          Left errs -> length errs == 3
          Right _ -> False
    it "succeeds on an empty list" $
      validateAll ([] :: [Either ValidationError Text]) `shouldBe` Right []

  describe "formatErrors" $ do
    it "formats RequiredFieldMissing" $
      formatErrors [RequiredFieldMissing "name"] `shouldBe` "Missing required field: name\n"
    it "formats InvalidFormat" $
      formatErrors [InvalidFormat "email" "must contain @ and ."] `shouldBe` "Invalid email: must contain @ and .\n"
    it "formats CustomError" $
      formatErrors [CustomError "Field cannot be empty"] `shouldBe` "Field cannot be empty\n"
    it "formats DuplicateKey" $
      formatErrors [DuplicateKey "id"] `shouldBe` "Duplicate key: id\n"
    it "formats multiple errors as separate lines" $
      formatErrors [RequiredFieldMissing "a", RequiredFieldMissing "b"]
        `shouldBe` "Missing required field: a\nMissing required field: b\n"

  describe "validateUnique" $ do
    it "accepts a list with no duplicates" $
      validateUnique "id" [1, 2, 3] `shouldBe` Right [1, 2, 3]
    it "rejects a list with duplicates" $
      validateUnique "id" [1, 2, 2, 3] `shouldSatisfy` isLeft
    it "accepts an empty list" $
      validateUnique "id" [] `shouldBe` Right ([] :: [Int])
    it "accepts a single-element list" $
      validateUnique "id" [42] `shouldBe` Right [42]

  describe "ValidationError properties" $ do
    it "validateEmail always accepts valid emails" $ property $
      \ (ValidEmail email) -> validateEmail email `shouldSatisfy` isRight
    it "validateRange is inclusive on both boundaries" $ property $
      \(lo :: Int) (hi :: Int) -> lo <= hi ==>
        (validateRange "x" lo (lo, hi) `shouldBe` Right lo)
        .&&. (validateRange "x" hi (lo, hi) `shouldBe` Right hi)
    it "validateNonEmpty rejects blank but accepts non-blank" $ property $
      \ (NonBlankText t) -> validateNonEmpty t `shouldSatisfy` isRight

  where
    isLeft (Left _) = True
    isLeft (Right _) = False
    isRight (Right _) = True
    isRight (Left _) = False
