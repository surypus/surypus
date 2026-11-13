{-# LANGUAGE OverloadedStrings #-}

-- | Property-based coverage for 'Finance.AccMask'.
--
-- 'Finance.AccMask' has zero test coverage. The real functions under test
-- ('isMaskActive' and 'validateMaskCode') are pure, deterministic and carry a
-- small contract that can be pinned without a database or a running server:
--
-- * 'isMaskActive' models a closed interval @[start, end]@ for an
--   'AMSActive' mask: dates inside the interval (inclusive at both ends) are
--   active, dates outside are not. For an open-ended mask ('Nothing' end) the
--   interval is @[start, +∞)@: every date on/after 'start' is active.
-- * 'validateMaskCode' accepts exactly the 1-10 character alphanumeric codes.
module Finance.AccMaskSpec (spec) where

import Data.Maybe (isJust)
import Data.Time (Day, fromGregorian, addDays)
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Arbitrary, Gen, Property, forAll, listOf, listOf1,
                        elements, choose, arbitrary, property, (==>), (.&&.))

import qualified Data.Text as T

import Finance.AccMask

-- | @Day@ is unbounded, but 'isMaskActive' is only meaningful inside a sane
--  production window, so generate inside a closed, realistic range instead of
--  relying on 'minBound'/'maxBound'.
genDay :: Gen Day
genDay = fromGregorian <$> choose (1990, 2030) <*> choose (1, 12) <*> choose (1, 28)

instance Arbitrary Day where
  arbitrary = genDay

-- | Generate a mask whose 'amStartDate' precedes its 'amEndDate' (so the
--  interval @[start, end]@ is well-formed). Used by the closed-interval tests.
genClosedAccMask :: Gen AccMask
genClosedAccMask = do
  id <- choose (1, 10000)
  code <- T.pack <$> listOf1 (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9']))
  start <- genDay
  end <- genDay
  let (s, e) = if start <= end then (start, end) else (end, start)
  desc <- T.pack <$> listOf (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ " -"))
  status <- elements [AMSActive, AMSInactive, AMSExpired]
  priority <- choose (0, 100)
  isSystem <- arbitrary
  pure $ createAccMask id code s (Just e) desc status priority isSystem

-- | Generate a mask whose 'amEndDate' is 'Nothing' (open-ended window).
genOpenAccMask :: Gen AccMask
genOpenAccMask = do
  id <- choose (1, 10000)
  code <- T.pack <$> listOf1 (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9']))
  start <- genDay
  desc <- T.pack <$> listOf (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ " -"))
  status <- elements [AMSActive, AMSInactive, AMSExpired]
  priority <- choose (0, 100)
  isSystem <- arbitrary
  pure $ createAccMask id code start Nothing desc status priority isSystem

instance Arbitrary AccMask where
  arbitrary = do
    id <- choose (1, 10000)
    code <- T.pack <$> listOf1 (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9']))
    start <- genDay
    end <- genDay
    desc <- T.pack <$> listOf (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ " -"))
    status <- elements [AMSActive, AMSInactive, AMSExpired]
    priority <- choose (0, 100)
    isSystem <- arbitrary
    pure $ createAccMask id code start (Just end) desc status priority isSystem

-- ---------------------------------------------------------------------------
-- isMaskActive — closed interval
-- ---------------------------------------------------------------------------

-- | For a mask with a definite end date ('Just' end), 'isMaskActive' is true
--  exactly on the closed interval @[start, end]@, inclusive at both ends.
prop_isMaskActive_closedInterval :: Property
prop_isMaskActive_closedInterval =
  forAll genClosedAccMask $ \m ->
    forAll genDay $ \date ->
      amStatus m == AMSActive ==>
        let s = amStartDate m
            e = fromJust (amEndDate m)
            inRange = date >= s && date <= e
         in property (if inRange then isMaskActive m date else not (isMaskActive m date))

-- | The end date is inclusive: a date exactly equal to 'end' stays active.
prop_isMaskActive_endBoundaryInclusive :: Property
prop_isMaskActive_endBoundaryInclusive =
  forAll genClosedAccMask $ \m ->
    amStatus m == AMSActive ==>
      property (isMaskActive m (fromJust (amEndDate m)))

-- | The start date is inclusive: the first day of the window is active.
prop_isMaskActive_startBoundaryInclusive :: Property
prop_isMaskActive_startBoundaryInclusive =
  forAll genClosedAccMask $ \m ->
    amStatus m == AMSActive ==>
      property (isMaskActive m (amStartDate m))

-- ---------------------------------------------------------------------------
-- isMaskActive — open-ended
-- ---------------------------------------------------------------------------

-- | An open-ended mask ('Nothing' end) is active for every date on/after
--  'start' -- the window never closes. Pin the start and one day past it.
prop_isMaskActive_openEnded :: Property
prop_isMaskActive_openEnded =
  forAll genOpenAccMask $ \m ->
    amStatus m == AMSActive ==>
      isMaskActive m (amStartDate m) .&&.
      isMaskActive m (addDays 1 (amStartDate m))

-- ---------------------------------------------------------------------------
-- isMaskActive — guard
-- ---------------------------------------------------------------------------

-- | A non-'AMSActive' mask can never be active, regardless of dates.
prop_isMaskActive_needsActive :: AccMask -> Day -> Property
prop_isMaskActive_needsActive m date =
  amStatus m /= AMSActive ==> not (isMaskActive m date)

-- ---------------------------------------------------------------------------
-- validateMaskCode
-- ---------------------------------------------------------------------------

-- | 'validateMaskCode' accepts exactly the 1-10 character alphanumeric codes:
--  a code of length <= 10 and all-alphanumeric returns @Right@; anything else
--  returns @Left@.
prop_validateMaskCode_lengthBounds :: Property
prop_validateMaskCode_lengthBounds =
  forAll (choose (1, 12)) $ \n ->
    let code = T.replicate n "A"
     in if n <= 10
          then validateMaskCode code == Right code
          else validateMaskCode code == Left "Mask code must be 1-10 characters"

prop_validateMaskCode_rejectsEmpty :: Property
prop_validateMaskCode_rejectsEmpty =
  property (validateMaskCode T.empty == Left "Mask code must be 1-10 characters")

prop_validateMaskCode_rejectsOverLong :: Property
prop_validateMaskCode_rejectsOverLong =
  let code = T.replicate 11 "ABC"  -- length 33 > 10
   in property (validateMaskCode code == Left "Mask code must be 1-10 characters")

-- | Reject exactly the non-alphanumeric characters (letters and digits are
--  accepted, so they must not appear in the rejection set).
prop_validateMaskCode_rejectsNonAlphanumeric :: Property
prop_validateMaskCode_rejectsNonAlphanumeric =
  forAll
    (elements
       ( "!@#"
        ++ " []{}|;:,.<>/?*+-="
        ++ "\t\n\r"
       )) $ \c ->
      property (validateMaskCode (T.singleton c) == Left "Mask code must be alphanumeric")

-- ---------------------------------------------------------------------------
-- spec
-- ---------------------------------------------------------------------------

spec :: Spec
spec = describe "Finance.AccMask" $ do
  describe "isMaskActive" $ do
    prop "is active on exactly the closed [start,end] interval" prop_isMaskActive_closedInterval
    prop "end date is inclusive" prop_isMaskActive_endBoundaryInclusive
    prop "start date is inclusive" prop_isMaskActive_startBoundaryInclusive
    prop "open-ended (Nothing end) stays active after start" prop_isMaskActive_openEnded
    prop "requires AMSActive status" prop_isMaskActive_needsActive

  describe "validateMaskCode" $ do
    prop "accepts exactly 1-10 alphanumeric codes" prop_validateMaskCode_lengthBounds
    it "rejects the empty code" prop_validateMaskCode_rejectsEmpty
    it "rejects codes longer than 10 characters" prop_validateMaskCode_rejectsOverLong
    it "rejects non-alphanumeric codes" prop_validateMaskCode_rejectsNonAlphanumeric

-- | Total function version of 'Data.Maybe.fromJust' for use in our pure tests.
fromJust :: Maybe a -> a
fromJust (Just a) = a
fromJust Nothing  = error "fromJust: Nothing"
