{-# LANGUAGE OverloadedStrings #-}

-- | Tests for the WebSocket notification payloads.
--
-- The broadcast functions need a live connection, so the pure payload builders
-- are covered here and the broadcast entry points are exercised against an empty
-- handler (no subscribers), which must be a no-op rather than an error.
module Surypus.WebSocketSpec (spec) where

import Data.Aeson (Value (..), decode, object, (.=))
import qualified Data.ByteString.Lazy as LBS
import Data.Int (Int64)
import Data.Text (Text)
import Data.Text.Encoding (encodeUtf8)
import Surypus.WebSocket
import Test.Hspec

spec :: Spec
spec = do
  describe "inventoryEventJSON" $ do
    it "carries the goods id, event type and payload" $
      decode (payload 42 "stock_changed" (object ["qty" .= (5 :: Int)]))
        `shouldBe` Just
          ( object
              [ "goodsId" .= (42 :: Int64)
              , "eventType" .= ("stock_changed" :: Text)
              , "data" .= object ["qty" .= (5 :: Int)]
              ]
          )

  describe "dashboardEventJSON" $ do
    it "carries the event type and payload" $
      decode (LBS.fromStrict (encodeUtf8 (dashboardEventJSON "kpi_updated" (object ["revenue" .= (100 :: Int)]))))
        `shouldBe` Just
          ( object
              [ "eventType" .= ("kpi_updated" :: Text)
              , "data" .= object ["revenue" .= (100 :: Int)]
              ]
          )

  describe "broadcast entry points" $ do
    it "are a no-op on a handler with no subscribers" $ do
      handler <- initWebSocketHandler
      broadcastGlobal handler "hello"
      broadcastToInventoryRoom handler "stock"
      broadcastToDashboardRoom handler "kpi"
      broadcastInventoryEvent handler 1 "stock_changed" (String "v")
      broadcastDashboardEvent handler "kpi_updated" (String "v")
      pure ()

  where
    payload gid etype val = LBS.fromStrict (encodeUtf8 (inventoryEventJSON gid etype val))
