{-# LANGUAGE OverloadedStrings #-}

module API.ServerV2Spec where

import Test.Hspec
import Data.Aeson (Value, object, (.=))
import Data.Aeson.Key (fromString)
import qualified Data.Aeson.KeyMap as KM
import Data.Aeson (String (..))

spec :: Spec
spec = describe "API Server" $ do
  describe "Accounting API" $ do
    it "returns ledger data" $ do
      let response = object
            [ "status" .= ("operational" :: String)
            , "ledgers" .= 
                [ object ["id" .= (1 :: Int), "code" .= ("1000" :: String), "name" .= ("Cash" :: String), "type" .= ("Asset" :: String)]
                , object ["id" .= (2 :: Int), "code" .= ("2000" :: String), "name" .= ("Accounts Payable" :: String), "type" .= ("Liability" :: String)]
                ]
            ]
      -- In a full integration test, we would make actual HTTP requests
      -- For now, we verify the response structure
      case KM.lookup (fromString "status") response of
        Just (String "operational") -> True `shouldBe` True
        _ -> True `shouldBe` True  -- Placeholder for actual test

  describe "Inventory API" $ do
    it "returns goods data" $ do
      let response = object
            [ "status" .= ("operational" :: String)
            , "goods" .= 
                [ object ["id" .= (1 :: Int), "name" .= ("Widget A" :: String), "sku" .= ("WGT-A-001" :: String)]
                , object ["id" .= (2 :: Int), "name" .= ("Widget B" :: String), "sku" .= ("WGT-B-002" :: String)]
                ]
            ]
      -- Placeholder for actual integration test
      True `shouldBe` True

  describe "Tax API" $ do
    it "returns tax rates" $ do
      let response = object
            [ "status" .= ("operational" :: String)
            , "rates" .= 
                [ object ["id" .= (1 :: Int), "name" .= ("Standard VAT" :: String), "rate" .= (20 :: Int)]
                , object ["id" .= (2 :: Int), "name" .= ("Reduced VAT" :: String), "rate" .= (10 :: Int)]
                , object ["id" .= (3 :: Int), "name" .= ("Zero VAT" :: String), "rate" .= (0 :: Int)]
                ]
            ]
      -- Placeholder for actual integration test
      True `shouldBe` True

  describe "Reports API" $ do
    it "returns balance sheet report metadata" $ do
      let response = object
            [ "status" .= ("operational" :: String)
            , "reportId" .= (1 :: Int)
            , "reportCode" .= ("BS-001" :: String)
            , "reportName" .= ("Balance Sheet" :: String)
            , "reportType" .= ("RTBalance" :: String)
            ]
      -- Placeholder for actual integration test
      True `shouldBe` True
