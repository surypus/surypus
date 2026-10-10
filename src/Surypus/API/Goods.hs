
{-# LANGUAGE OverloadedStrings #-}
-- | Surypus API Goods (Phase 1: stub)
module Surypus.API.Goods
  ( listGoods
  , createGood
  , getGood
  , deleteGood
  ) where

import DAL.Types (Goods(..), QueryResult(..))
import Data.Int (Int64)

-- | List goods (stub)
listGoods :: Int64 -> IO (QueryResult [Goods])
listGoods _ = return $ QuerySuccess []

-- | Create good (stub)
createGood :: Goods -> IO (QueryResult Int64)
createGood _ = return $ QuerySuccess 0

-- | Get good (stub)
getGood :: Int64 -> IO (QueryResult Goods)
getGood _ = return $ QueryError "Not found"

-- | Delete good (stub)
deleteGood :: Int64 -> IO (QueryResult ())
deleteGood _ = return $ QuerySuccess ()
