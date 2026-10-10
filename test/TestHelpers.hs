{-# LANGUAGE OverloadedStrings #-}

-- | Shared test helpers and property-based tests for Surypus.
-- This module is part of the surypus-test test-suite.
module TestHelpers
  ( specBillLines,
    specPayroll,
    specProduction,
    specInventory,
    prop_bill_post_total_equals_sum_of_lines,
    prop_salary_amount_nonnegative,
    prop_work_order_released_le_planned,
    prop_bill_line_total_nonnegative,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime (..), secondsToDiffTime)
import Data.Time.Calendar (fromGregorian)
import HR.Types (SalaryRecord (..))
import Network.Wai (Application)
import Production.Types (WorkOrder (..))
import Surypus.Types.Bill (Bill (..), BillLine (..), BillStatus (..))
import Test.Hspec
import Test.QuickCheck

-- | Non-negative Int generator
genNonNegInt :: Gen Int
genNonNegInt = choose (0, 1000)

-- | Non-negative Int64 generator
genNonNegInt64 :: Gen Int64
genNonNegInt64 = choose (0, 1000)

-- | Non-negative Double generator
genNonNegDouble :: Gen Double
genNonNegDouble = choose (0.0, 1000.0)

-- | Positive Int generator
genPosInt :: Gen Int
genPosInt = choose (1, 1000)

-- | Positive Int64 generator
genPosInt64 :: Gen Int64
genPosInt64 = choose (1, 1000)

-- | Generate a non-empty text string
genNonEmptyText :: Gen Text
genNonEmptyText = T.pack <$> listOf1 (elements (['a'..'z'] ++ ['0'..'9']))

instance Arbitrary Text where
  arbitrary = genNonEmptyText

-- | Shared test server (placeholder — requires running server)
withTestServer :: IO Application
withTestServer = error "withTestServer: not implemented — requires running API server"

-- | API test helpers
specBillLines :: SpecWith ()
specBillLines = describe "Bill Lines" $ do
  it "requires authentication" $ do
    pending

  it "requires BillPost permission" $ do
    pending

specPayroll :: SpecWith ()
specPayroll = describe "Payroll" $ do
  it "GET /hr/charges requires auth" $ pending
  it "POST /hr/salaries requires BillPost permission" $ pending

specProduction :: SpecWith ()
specProduction = describe "Production" $ do
  it "work-order CRUD" $ pending

specInventory :: SpecWith ()
specInventory = describe "Inventory" $ do
  it "POST /inventory requires auth" $ pending

-- | Property: bill total equals sum of line totals
prop_bill_post_total_equals_sum_of_lines :: Bill -> Property
prop_bill_post_total_equals_sum_of_lines bill =
  property $ billAmount bill == sum (map lineTotal (billLines bill))

-- | Property: salary amount is non-negative
prop_salary_amount_nonnegative :: SalaryRecord -> Bool
prop_salary_amount_nonnegative = (>= 0) . salaryRecordAmount

-- | Property: work order released never exceeds planned
prop_work_order_released_le_planned :: WorkOrder -> Bool
prop_work_order_released_le_planned wo = woQtyReleased wo <= woQtyPlan wo

-- | Property: bill line total is non-negative
prop_bill_line_total_nonnegative :: BillLine -> Bool
prop_bill_line_total_nonnegative = (>= 0) . lineTotal

-- ============================================================================
-- Arbitrary instances for property-based testing
-- ============================================================================

-- | Generate a valid UTCTime for testing
genValidUTCTime :: Gen UTCTime
genValidUTCTime = do
  year <- choose (2020, 2030) :: Gen Integer
  month <- choose (1, 12) :: Gen Int
  day <- choose (1, 28) :: Gen Int
  hour <- choose (0, 23) :: Gen Int
  minute <- choose (0, 59) :: Gen Int
  second <- choose (0, 59) :: Gen Int
  return $ UTCTime (fromGregorian year month day)
                  (secondsToDiffTime $ fromIntegral hour * 3600 + fromIntegral minute * 60 + fromIntegral second)

instance Arbitrary UTCTime where
  arbitrary = genValidUTCTime

instance Arbitrary BillStatus where
  arbitrary = elements [Draft, Posted, Cancelled, Archived]

-- | Generate a BillLine with non-negative quantity and price,
-- and lineTotal = quantity * price (always non-negative)
instance Arbitrary BillLine where
  arbitrary = do
    lid <- genPosInt64
    lbid <- genPosInt64
    lgid <- genPosInt64
    qty <- genPosInt
    price <- genNonNegDouble
    taxRate <- frequency [(1, return Nothing), (3, Just <$> choose (0.0, 100.0))]
    let total = fromIntegral qty * price
    return $ BillLine lid lbid lgid qty price total taxRate

-- | Generate a Bill whose billAmount equals the sum of line totals
instance Arbitrary Bill where
  arbitrary = do
    lines <- listOf1 arbitrary
    let total = sum (map lineTotal lines)
    t <- arbitrary
    num <- genNonEmptyText
    return $ Bill
      { billId = 0 :: Int64
      , billNumber = num
      , billStatus = Draft
      , billAmount = total
      , billLines = lines
      , billCreatedAt = t
      , billUpdatedAt = Just t
      , billPersonId = Just 1
      , billLocationId = Nothing
      }

instance Arbitrary SalaryRecord where
  arbitrary = do
    rid <- genPosInt64
    amt <- choose (0.0, 10000.0)
    return $ SalaryRecord rid amt

-- | Generate a WorkOrder with woQtyReleased <= woQtyPlan
instance Arbitrary WorkOrder where
  arbitrary = do
    plan <- choose (0.0, 1000.0)
    released <- choose (0.0, plan)
    t <- arbitrary
    code <- genNonEmptyText
    return $ WorkOrder
      { woId = Nothing :: Maybe Int64
      , woCode = code
      , woGoodsId = 1
      , woTechCardId = Nothing
      , woQtyPlan = plan
      , woQtyReleased = released
      , woStatus = 0
      , woStartDate = Just t
      , woEndDate = Nothing
      , woProcessorId = Nothing
      , woNotes = Nothing
      , woCreatedAt = t
      , woUpdatedAt = t
      , woCreatedBy = Nothing
      }
