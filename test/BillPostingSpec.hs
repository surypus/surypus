module BillPostingSpec (spec) where

import Service.BillPosting (balancedEntries)
import Test.Hspec
import Test.QuickCheck

spec :: Spec
spec = describe "balancedEntries" $ do
  it "has exactly two entries for a non-negative total" $
    property $ \total -> total >= 0 ==> length (balancedEntries total) === 2

  it "keeps debit equal to credit" $
    property $ \total ->
      let entries = balancedEntries total
       in sum (map fst entries) === sum (map snd entries)

  it "has no negative amounts" $
    property $ \total -> total >= 0 ==> all (\(d, c) -> d >= 0 && c >= 0) (balancedEntries total)

  it "rejects a negative total" $
    balancedEntries (-1) `shouldBe` []
