{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Goods (
    listGoods,
    createGood,
    getGood,
    updateGood,
    deleteGood,
)
where

import DAL.Pool (ConnectionPool)
import qualified DAL.Mutations as Mut
import qualified DAL.QueriesORM as ORM
import DAL.Types (Goods (..), GoodsInput (..), MutationResult (..), QueryResult (..))
import Data.Int (Int64)

listGoods :: ConnectionPool -> IO (QueryResult [Goods])
listGoods = ORM.getGoods

createGood :: ConnectionPool -> GoodsInput -> IO (QueryResult Goods)
createGood pool input = do
    result <- Mut.createGoods pool input
    case result of
        QuerySuccess (MutationResult _ (Just rid) _) -> ORM.getGoodsById pool rid
        QuerySuccess _ -> return $ QueryError "Created but no ID returned"
        QueryError err -> return $ QueryError err

getGood :: ConnectionPool -> Int64 -> IO (QueryResult Goods)
getGood = ORM.getGoodsById

updateGood :: ConnectionPool -> Int64 -> GoodsInput -> IO (QueryResult Goods)
updateGood pool gid input = do
    result <- Mut.updateGoods pool gid input
    case result of
        QuerySuccess _ -> ORM.getGoodsById pool gid
        QueryError err -> return $ QueryError err

deleteGood :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteGood pool gid = do
    result <- Mut.deleteGoods pool gid
    case result of
        QuerySuccess _ -> return $ QuerySuccess ()
        QueryError err -> return $ QueryError err
