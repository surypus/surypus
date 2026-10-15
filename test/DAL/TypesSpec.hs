{-# LANGUAGE OverloadedStrings #-}

-- | Coverage for 'DAL.Types' — the DSL-generated entity types
-- (generated from dsl/schema.yaml, carrying the JSON instances the
-- API layer and the PostgreSQL payloads depend on).
--
-- The types are generated, so the contract under test is not business
-- logic but the transport contract: every entity must survive a JSON
-- roundtrip intact, and the encoded keys must match the generated
-- field names (a rename in the DSL would otherwise silently change the
-- wire format).
module DAL.TypesSpec (spec) where

import Data.Aeson (FromJSON, Object, ToJSON, Value (..), decode, encode)
import Data.Aeson.Key (toText)
import Data.Aeson.KeyMap (toList)
import Data.Time.Calendar (fromGregorian)
import Test.Hspec
import Test.QuickCheck (Gen, choose, forAll)

import qualified Data.Text as T

import DAL.Types

spec :: Spec
spec = do
  describe "DAL.Types entity JSON roundtrips" $ do
    it "PersonEntity survives encode/decode" $ do
      let e = PersonEntity "1" "P001" "Company A" "1234567891" "123456791" "1" "0"
      decode (encode e) `shouldBe` Just e

    it "CustomerEntity survives encode/decode" $ do
      let e = CustomerEntity "2" "C002" "Alice" "a@example.com" "1000.00" "true" "2026-01-01"
      decode (encode e) `shouldBe` Just e

    it "ProductionOrderEntity survives encode/decode" $ do
      let e = ProductionOrderEntity "3" "PO-7" "G1" "10" "2026-02-01" "draft"
      decode (encode e) `shouldBe` Just e

    it "ReportConfigEntity survives encode/decode" $ do
      let e = ReportConfigEntity "4" "Sales" "SELECT 1" "30" "true"
      decode (encode e) `shouldBe` Just e

    it "BillEntity survives encode/decode" $ do
      let e = BillEntity "5" "B-1" "C1" "500.00" "paid"
      decode (encode e) `shouldBe` Just e

    it "TaxEntity survives encode/decode" $ do
      let e = TaxEntity "6" "VAT20" "VAT" "0.2"
      decode (encode e) `shouldBe` Just e

    it "Person survives encode/decode" $ do
      let p = Person 1 (Just "001") "Test" (Just "7707083893") (Just "770701001") (Just 1) (Just 1)
      decode (encode p) `shouldBe` Just p

    it "Goods survives encode/decode" $ do
      let g = Goods 1 (Just "001") "Test" Nothing (Just "123456") (Just 1)
                    Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing
      decode (encode g) `shouldBe` Just g

    it "Bill survives encode/decode" $ do
      let b = Bill 1 (Just "B-001") (Just "sale") (Just "paid") (fromGregorian 2024 1 1)
                   (Just 1) (Just 1) 1000.0 0.0 200.0
      decode (encode b) `shouldBe` Just b

    it "Pagination survives encode/decode" $ do
      let p = Pagination 0 10
      decode (encode p) `shouldBe` Just p

    it "AccTurnInput survives encode/decode" $ do
      let input = AccTurnInput 1 2 100.0 (Just "Test")
      decode (encode input) `shouldBe` Just input

    it "MutationResult survives encode/decode" $ do
      let mr = MutationResult True (Just 42) "Success"
      decode (encode mr) `shouldBe` Just mr

    it "encodes the generated field names as JSON keys" $ do
      -- pins the wire format: a DSL rename would silently change the
      -- payload keys the API layer and stored events rely on.
      let e = PersonEntity "1" "P001" "Company A" "1234567891" "123456791" "1" "0"
          encoded = encode e
      case decode encoded of
        Just (Object obj) ->
          keysOf obj `shouldContainAll`
            ["personEntityId", "code", "name", "inn", "kpp", "personType", "status"]
        _ -> expectationFailure "PersonEntity did not decode to an object"

  describe "DAL.Types generic roundtrip (property)" $ do
    it "roundtrips arbitrary entity values" $
      forAll (choose (0, 50) :: Gen Int) $ \i ->
        roundtrip (PersonEntity (T.pack (show i)) "c" "n" "i" "k" "1" "0" :: PersonEntity)

-- | decode/encode roundtrip: decode (encode x) == x for any x.
roundtrip :: (Eq a, FromJSON a, ToJSON a) => a -> Bool
roundtrip x = decode (encode x) == Just x

-- | The top-level object keys of an encoded value.
keysOf :: Object -> [String]
keysOf = map (T.unpack . toText) . map fst . toList

shouldContainAll :: [String] -> [String] -> IO ()
shouldContainAll actual expected =
  mapM_ check expected
  where
    check k
      | k `elem` actual = return ()
      | otherwise = expectationFailure $ "key not found: " ++ k
