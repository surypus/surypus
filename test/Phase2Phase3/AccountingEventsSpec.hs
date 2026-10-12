module Phase2Phase3.AccountingEventsSpec (spec) where

import Data.Text (pack)
import Data.Time (getCurrentTime)
import Domain.Accounting.Events (AccountingEvent (..), rebuildBalance)
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Accounting Event replay" $ do
    it "rebuildBalance computes correct result from events" $ do
      t <- getCurrentTime
      let evs =
            [ EntryCreated 1 1 (pack "4001") 1000 0 (pack "dep") t,
              EntryCreated 2 1 (pack "4001") 0 500 (pack "dep") t
            ]
          balance = rebuildBalance (pack "4001") evs
      balance `shouldBe` 500.0
