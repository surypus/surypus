{-# LANGUAGE OverloadedStrings #-}

-- | MoreAssertLike provides assertions with more informative error messages,
--   especially useful for test cases where default error messages are insufficient.
module Test.MoreAssertLike
  ( assertEqualWith,
    assertBoolWith,
    assertListEqualWith,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import Test.Hspec

-- | Assert that two values are equal, with a custom message if they are not.
--   The custom message is shown in addition to the standard diff.
assertEqualWith :: (Eq a, Show a) => Text -> a -> a -> Expectation
assertEqualWith msg expected actual =
  if expected == actual
    then pure ()
    else expectationFailure $ T.unpack msg ++ ": expected " ++ show expected ++ ", got " ++ show actual

-- | Assert that a condition is True, with a custom message if it is False.
assertBoolWith :: Text -> Bool -> Expectation
assertBoolWith msg condition =
  if condition
    then pure ()
    else expectationFailure $ T.unpack msg

-- | Assert that two lists are equal, with a custom message if they are not.
--   This is particularly useful for showing the difference in long lists.
assertListEqualWith :: (Eq a, Show a) => Text -> [a] -> [a] -> Expectation
assertListEqualWith msg expected actual =
  if expected == actual
    then pure ()
    else expectationFailure $ T.unpack msg ++ ": expected " ++ show expected ++ ", got " ++ show actual
