{-# LANGUAGE OverloadedStrings #-}
module System.Validation where

import Data.Either (partitionEithers)
import Data.List (nub, (\\))
import Data.Text (Text)
import qualified Data.Text as T

-- | Validation result type
data ValidationError
  = RequiredFieldMissing Text
  | InvalidFormat Text Text
  | OutOfRange Text Double (Double, Double)
  | DuplicateKey Text
  | CustomError Text
  deriving (Show, Eq)

-- | Validation result
newtype ValidationResult a = ValidationResult
  { getValidationResult :: Either [ValidationError] a
  }

-- | Validate required field
validateRequired :: Text -> Maybe a -> Either ValidationError a
validateRequired fieldName Nothing =
  Left $ RequiredFieldMissing fieldName
validateRequired _ (Just val) = Right val

-- | Validate email format
validateEmail :: Text -> Either ValidationError Text
validateEmail email =
  if "@" `T.isInfixOf` email && "." `T.isInfixOf` email
    then Right email
    else Left $ InvalidFormat "email" "must contain @ and ."

-- | Validate range
validateRange :: (Ord a, Show a, Read a) => Text -> a -> (a, a) -> Either ValidationError a
validateRange fieldName val (minVal, maxVal)
  | val >= minVal && val <= maxVal = Right val
  | otherwise = Left $ OutOfRange fieldName (read (show val) :: Double) (read (show minVal) :: Double, read (show maxVal) :: Double)

-- | Validate non-empty
validateNonEmpty :: Text -> Either ValidationError Text
validateNonEmpty val =
  if T.null (T.strip val)
    then Left $ CustomError "Field cannot be empty"
    else Right val

-- | Combine validations
validateAll :: [Either ValidationError a] -> Either [ValidationError] [a]
validateAll validations =
  let (errors, successes) = partitionEithers validations
  in if null errors
       then Right successes
       else Left errors

-- | Validation helper
(<*>) :: Either [ValidationError] (a -> b) -> Either [ValidationError] a -> Either [ValidationError] b
(Left errs1) <*> _ = Left errs1
(Right _) <*> (Left errs2) = Left errs2
(Right f) <*> (Right x) = Right (f x)

infixl 4 <*>

-- | Error message formatting
formatErrors :: [ValidationError] -> Text
formatErrors = T.unlines . map formatError
  where
    formatError (RequiredFieldMissing field) = "Missing required field: " <> field
    formatError (InvalidFormat field reason) = "Invalid " <> field <> ": " <> reason
    formatError (OutOfRange field val (minVal, maxVal)) =
      field <> " out of range: " <> T.pack (show val) <> " (expected " <> T.pack (show minVal) <> "-" <> T.pack (show maxVal) <> ")"
    formatError (DuplicateKey key) = "Duplicate key: " <> key
    formatError (CustomError msg) = msg

-- | Validate list uniqueness
validateUnique :: (Eq a) => Text -> [a] -> Either ValidationError [a]
validateUnique fieldName list =
  let duplicates = findDuplicates list
   in if null duplicates
        then Right list
        else Left $ DuplicateKey fieldName
  where
    findDuplicates xs = xs \\ nub xs
