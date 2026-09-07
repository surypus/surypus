{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Persons (
    listPersons,
    createPerson,
    getPerson,
    updatePerson,
    deletePerson,
    searchPersons,
)
where

import DAL.Pool (ConnectionPool)
import qualified DAL.Mutations as Mut
import qualified DAL.QueriesORM as ORM
import DAL.Types (MutationResult (..), Person (..), PersonInput (..), QueryResult (..))
import Data.Int (Int64)
import qualified Data.Text as T

listPersons :: ConnectionPool -> Maybe String -> Maybe String -> Maybe Int -> Maybe Int -> Maybe Int -> IO (QueryResult [Person])
listPersons pool _ _ _ _ _ = ORM.getPersons pool

createPerson :: ConnectionPool -> PersonInput -> IO (QueryResult MutationResult)
createPerson = Mut.createPerson

getPerson :: ConnectionPool -> Int64 -> IO (QueryResult Person)
getPerson = ORM.getPersonById

updatePerson :: ConnectionPool -> Int64 -> PersonInput -> IO (QueryResult MutationResult)
updatePerson = Mut.updatePerson

deletePerson :: ConnectionPool -> Int64 -> IO (QueryResult ())
deletePerson pool pid = do
    result <- Mut.deletePerson pool pid
    case result of
        QuerySuccess _ -> return $ QuerySuccess ()
        QueryError err -> return $ QueryError err

searchPersons :: ConnectionPool -> String -> IO (QueryResult [Person])
searchPersons pool query = ORM.searchPersons pool (T.pack query)
