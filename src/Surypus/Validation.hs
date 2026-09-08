-- | Validation module - Input validation utilities
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
module Surypus.Validation
  ( ValidationError   (..),
    validatePersonInput,
    validateINN,
    validateKPP,
    isValidINN,
    isValidKPP,
    isValidPhone,
    validateAccPlanInput,
    validateAccTurnInput,
    validateBillInput,
    validateCurrencyInput,
    validateGoodsInput,
    validateLocationInput,
    validateOrderInput,
    validatePaymentInput,
    validatePriceInput,
    validateTaxInput,
  )
where

import DAL.Types (AccTurnInput(..))
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (Day)

-- | Validation error types
data ValidationError
  = EmptyName
  | InvalidINN
  | InvalidKPP
  | InvalidAmount
  | InvalidDate
  | FieldTooLong Text
  | FieldRequired Text
  deriving (Show, Eq)

-- | INN validation (10 or 12 digits)
isValidINN :: Text -> Bool
isValidINN inn =
  case T.all (`elem` ['0' .. '9']) inn of
    True -> T.length inn == 10 || T.length inn == 12
    False -> False

-- | KPP validation (9 digits)
isValidKPP :: Text -> Bool
isValidKPP kpp =
  case T.all (`elem` ['0' .. '9']) kpp of
    True -> T.length kpp == 9
    False -> False

-- | Phone validation (10+ digits)
isValidPhone :: Text -> Bool
isValidPhone phone =
  let digits = T.filter (`elem` ['0' .. '9']) phone
   in T.length digits >= 10

-- | Validate person input
validatePersonInput :: Text -> Maybe Text -> Maybe Text -> Either ValidationError ()
validatePersonInput name _inn _kpp
  | T.null name || T.strip name == "" = Left EmptyName
  | otherwise = Right ()

-- | Validate INN string
validateINN :: Text -> Either ValidationError Text
validateINN inn
  | isValidINN inn = Right inn
  | otherwise = Left InvalidINN

-- | Validate KPP string
validateKPP :: Text -> Either ValidationError Text
validateKPP kpp
  | isValidKPP kpp = Right kpp
  | otherwise = Left InvalidKPP

-- | Validate account plan input
validateAccPlanInput :: Text -> Text -> Int -> Either ValidationError ()
validateAccPlanInput code name _accType
  | T.null code = Left (FieldRequired "code")
  | T.null name = Left (FieldRequired "name")
  | otherwise = Right ()

-- | Validate accounting turn input
validateAccTurnInput :: AccTurnInput -> Either ValidationError ()
validateAccTurnInput AccTurnInput {..}
  | atiDbtAccId <= 0 = Left (FieldRequired "debit account")
  | atiCrdAccId <= 0 = Left (FieldRequired "credit account")
  | atiAmount <= 0 = Left InvalidAmount
  | otherwise = Right ()

-- | Validate bill input
validateBillInput :: Text -> Either ValidationError ()
validateBillInput _code = Right ()

-- | Validate currency input
validateCurrencyInput :: Text -> Text -> Either ValidationError ()
validateCurrencyInput code _name
  | T.length code /= 3 = Left (FieldRequired "currency code (3 chars)")
  | otherwise = Right ()

-- | Validate goods input
validateGoodsInput :: Text -> Text -> Either ValidationError ()
validateGoodsInput name _article
  | T.null name = Left (FieldRequired "name")
  | otherwise = Right ()

-- | Validate location input
validateLocationInput :: Text -> Either ValidationError ()
validateLocationInput name
  | T.null name = Left (FieldRequired "name")
  | otherwise = Right ()

-- | Validate order input
validateOrderInput :: Text -> Either ValidationError ()
validateOrderInput _name = Right ()

-- | Validate payment input
validatePaymentInput :: Double -> Day -> Either ValidationError ()
validatePaymentInput amount _date
  | amount <= 0 = Left InvalidAmount
  | otherwise = Right ()

-- | Validate price input
validatePriceInput :: Double -> Either ValidationError ()
validatePriceInput price
  | price < 0 = Left InvalidAmount
  | otherwise = Right ()

-- | Validate tax input
validateTaxInput :: Text -> Double -> Either ValidationError ()
validateTaxInput name rate
  | T.null name = Left (FieldRequired "tax name")
  | rate < 0 || rate > 100 = Left InvalidAmount
  | otherwise = Right ()