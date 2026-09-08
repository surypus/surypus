{-# LANGUAGE OverloadedStrings #-}
-- | Surypus API Goods (Phase 1: stub)
module Surypus.API.Goods
  ( listGoods
  , createGood
  , getGood
  , updateGood
  , deleteGood
  ) where

import DAL.Types (Goods(..), QueryResult(..))
import Data.Int (Int64)

-- | List goods (stub)
listGoods :: Int64 -> IO (QueryResult [Goods])
listGoods _ = return $ QueryResults [] 0

-- | Create good (stub)
createGood :: Goods -> IO (QueryResult Int64)
createGood _ = return $ QueryResult [0] 1

-- | Get good (stub)
getGood :: Int64 -> IO (QueryResult Goods)
getGood _ = return $ QueryResults [] 0

-- | Update good (stub)
updateGood :: Goods -> IO (QueryResult ())
updateGood _ = return $ QueryResult [()] 1

-- | Delete good (stub)
deleteGood :: Int64 -> IO (QueryResult ())
deleteGood _ = return $ QueryResult [()] 1
