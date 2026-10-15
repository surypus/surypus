module Commerce.CashSessionTempSpec
  (spec)
where

import Commerce.CashSessionTemp
import Test.Hspec
import Test.QuickCheck

spec :: Spec
spec = do
  describe "emptyTempCashCheck" $ do
    it "creates an empty check (zero amounts, valid)" $ do
      let chk = emptyTempCashCheck 42 7
      totalAmount chk `shouldBe` 0.0
      totalDiscount chk `shouldBe` 0.0
      netAmount chk `shouldBe` 0.0
      verifyCheck chk `shouldBe` True

  describe "mkTempCheckLine" $ do
    it "accepts a line where amount equals discount" $ do
      mkTempCheckLine 1 100.0 100.0 `shouldSatisfy` isJust
    it "accepts a line where amount exceeds discount" $ do
      mkTempCheckLine 1 150.0 50.0 `shouldSatisfy` isJust
    it "rejects a line where amount is less than discount" $ do
      mkTempCheckLine 1 50.0 100.0 `shouldBe` Nothing
    it "accepts a zero-amount zero-discount line" $ do
      mkTempCheckLine 1 0.0 0.0 `shouldSatisfy` isJust

  describe "addTempCheckLine + totalAmount" $ do
    it "appends a line (totalAmount reflects it)" $ do
      let chk = emptyTempCashCheck 1 1
          line = case mkTempCheckLine 10 200.0 20.0 of Just l -> l; Nothing -> error "valid"
          chk' = addTempCheckLine chk line
      totalAmount chk' `shouldBe` 200.0
    it "preserves existing lines (accumulates)" $ do
      let chk = emptyTempCashCheck 1 1
          line1 = case mkTempCheckLine 10 200.0 20.0 of Just l -> l; Nothing -> error "valid"
          line2 = case mkTempCheckLine 20 300.0 30.0 of Just l -> l; Nothing -> error "valid"
          chk' = addTempCheckLine (addTempCheckLine chk line1) line2
      totalAmount chk' `shouldBe` 500.0

  describe "totalDiscount" $ do
    it "returns 0 for an empty check" $ do
      totalDiscount (emptyTempCashCheck 1 1) `shouldBe` 0.0
    it "sums single line discount" $ do
      let chk = emptyTempCashCheck 1 1
          line = case mkTempCheckLine 10 200.0 25.0 of Just l -> l; Nothing -> error "valid"
      totalDiscount (addTempCheckLine chk line) `shouldBe` 25.0
    it "sums multiple line discounts" $ do
      let chk = emptyTempCashCheck 1 1
          line1 = case mkTempCheckLine 10 200.0 20.0 of Just l -> l; Nothing -> error "valid"
          line2 = case mkTempCheckLine 20 300.0 30.0 of Just l -> l; Nothing -> error "valid"
          chk' = addTempCheckLine (addTempCheckLine chk line1) line2
      totalDiscount chk' `shouldBe` 50.0

  describe "netAmount" $ do
    it "returns 0 for an empty check" $ do
      netAmount (emptyTempCashCheck 1 1) `shouldBe` 0.0
    it "computes amount minus discount for a single line" $ do
      let chk = emptyTempCashCheck 1 1
          line = case mkTempCheckLine 10 200.0 30.0 of Just l -> l; Nothing -> error "valid"
      netAmount (addTempCheckLine chk line) `shouldBe` 170.0
    it "computes totalAmount minus totalDiscount for multiple lines" $ do
      let chk = emptyTempCashCheck 1 1
          line1 = case mkTempCheckLine 10 200.0 20.0 of Just l -> l; Nothing -> error "valid"
          line2 = case mkTempCheckLine 20 300.0 40.0 of Just l -> l; Nothing -> error "valid"
          chk' = addTempCheckLine (addTempCheckLine chk line1) line2
      netAmount chk' `shouldBe` 440.0
    it "equals totalAmount minus totalDiscount (consistency)" $ do
      let chk = emptyTempCashCheck 1 1
          line1 = case mkTempCheckLine 10 200.0 20.0 of Just l -> l; Nothing -> error "valid"
          line2 = case mkTempCheckLine 20 300.0 40.0 of Just l -> l; Nothing -> error "valid"
          chk' = addTempCheckLine (addTempCheckLine chk line1) line2
      netAmount chk' `shouldBe` totalAmount chk' - totalDiscount chk'

  describe "verifyCheck" $ do
    it "returns True for an empty check" $ do
      verifyCheck (emptyTempCashCheck 1 1) `shouldBe` True
    it "returns True for a valid check (amount >= discount)" $ do
      let chk = emptyTempCashCheck 1 1
          line = case mkTempCheckLine 10 200.0 50.0 of Just l -> l; Nothing -> error "valid"
      verifyCheck (addTempCheckLine chk line) `shouldBe` True

  describe "properties" $ do
    it "netAmount is never negative for valid checks" $ do
      forAll (choose (0, 1000)) $ \amt ->
        forAll (choose (0, amt)) $ \disc ->
          let line = case mkTempCheckLine 1 amt disc of Just l -> l; Nothing -> error "valid"
              chk = addTempCheckLine (emptyTempCashCheck 1 1) line
          in netAmount chk >= 0
    it "totalAmount >= totalDiscount for valid checks (the invariant)" $ do
      forAll (choose (0, 1000)) $ \amt1 ->
        forAll (choose (0, 1000)) $ \disc1 ->
          forAll (choose (0, 1000)) $ \amt2 ->
            forAll (choose (0, 1000)) $ \disc2 ->
              amt1 >= disc1 && amt2 >= disc2 ==>
                let line1 = case mkTempCheckLine 1 amt1 disc1 of Just l -> l; Nothing -> error "valid"
                    line2 = case mkTempCheckLine 2 amt2 disc2 of Just l -> l; Nothing -> error "valid"
                    chk = addTempCheckLine (addTempCheckLine (emptyTempCashCheck 1 1) line1) line2
                in verifyCheck chk
    it "adding a line increases totalAmount by the line amount" $ do
      forAll (choose (0, 1000)) $ \amt ->
        forAll (choose (0, amt)) $ \disc ->
          let line = case mkTempCheckLine 1 amt disc of Just l -> l; Nothing -> error "valid"
              chk0 = emptyTempCashCheck 1 1
              chk1 = addTempCheckLine chk0 line
          in totalAmount chk1 == totalAmount chk0 + amt

isJust :: Maybe a -> Bool
isJust (Just _) = True
isJust Nothing = False
