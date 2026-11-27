{-# LANGUAGE OverloadedStrings #-}
-- | Surypus API Goods — DAL-backed handlers.
module Surypus.API.Goods
  ( listGoods
  , createGood
  , getGood
  , deleteGood
  ) where

import DAL.Queries (getAllGoods, getGoodById)
import DAL.Types (Goods (..), QueryResult (..), mrId)
import qualified DAL.Mutations as Mutations
import Data.Int (Int64)
import Database.Persist.Postgresql (ConnectionPool)

listGoods :: ConnectionPool -> IO (QueryResult [Goods])
listGoods = getAllGoods

createGood :: ConnectionPool -> Goods -> IO (QueryResult Int64)
createGood pool good = mapId <$> Mutations.createGoods pool good
  where
    mapId (QuerySuccess mr) = QuerySuccess (maybe 0 id (mrId mr))
    mapId (QueryError e) = QueryError e
    mapId (QueryResults xs n) = QueryResults (maybe 0 id . mrId <$> xs) n

getGood :: ConnectionPool -> Int64 -> IO (QueryResult Goods)
getGood = getGoodById

deleteGood :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteGood pool gid = toUnit <$> Mutations.deleteGoods pool gid
  where
    toUnit (QuerySuccess _) = QuerySuccess ()
    toUnit (QueryError e) = QueryError e
    toUnit (QueryResults _ n) = QueryResults [] n
