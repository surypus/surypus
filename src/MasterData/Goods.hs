-- Master Data: Goods module — Phase 4 (manual fallback).
-- Defines canonical goods record with ID, name, price (Data.Decimal).
module MasterData.Goods (Goods(..), goodsPrice) where

import Finance.Types (Money)

data Goods = Goods
  { goodsId    :: Int
  , goodsName  :: String
  , goodsPrice :: Money
  } deriving (Eq, Show)
