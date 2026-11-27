{-# LANGUAGE OverloadedStrings #-}
-- | Surypus API Persons — DAL-backed handlers.
module Surypus.API.Persons
  ( listPersons
  , createPerson
  , getPerson
  , updatePerson
  , deletePerson
  , searchPersons
  ) where

import DAL.Queries (getAllPersons, getPersonById, searchPersonsByName)
import DAL.Types (Person (..), QueryResult (..), mrId)
import qualified DAL.Mutations as Mutations
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Postgresql (ConnectionPool)

listPersons :: ConnectionPool -> Maybe Text -> Maybe Text -> Maybe Int -> Maybe Int -> Maybe Int -> IO (QueryResult [Person])
listPersons pool mcode mname _mtype _mstatus mlimit = do
  result <- getAllPersons pool
  pure $ case result of
    QueryError e -> QueryError e
    QueryResults xs n -> QueryResults xs n
    QuerySuccess xs ->
      let filtered = filterPersons xs
          paged = maybe filtered (\lim -> take lim filtered) mlimit
      in QuerySuccess paged
  where
    filterPersons :: [Person] -> [Person]
    filterPersons = filter $ \p ->
      maybe True (\c -> personCode p == Just c) mcode
        && maybe True (\n -> n `T.isInfixOf` personName p) mname

createPerson :: ConnectionPool -> Person -> IO (QueryResult Int64)
createPerson pool person = mapId <$> Mutations.createPerson pool person
  where
    mapId (QuerySuccess mr) = QuerySuccess (maybe 0 id (mrId mr))
    mapId (QueryError e) = QueryError e
    mapId (QueryResults xs n) = QueryResults (maybe 0 id . mrId <$> xs) n

getPerson :: ConnectionPool -> Int64 -> IO (QueryResult Person)
getPerson = getPersonById

updatePerson :: ConnectionPool -> Int64 -> Person -> IO (QueryResult ())
updatePerson pool pid person = toUnit <$> Mutations.updatePerson pool pid person
  where
    toUnit (QuerySuccess _) = QuerySuccess ()
    toUnit (QueryError e) = QueryError e
    toUnit (QueryResults _ n) = QueryResults [] n

deletePerson :: ConnectionPool -> Int64 -> IO (QueryResult ())
deletePerson pool pid = toUnit <$> Mutations.deletePerson pool pid
  where
    toUnit (QuerySuccess _) = QuerySuccess ()
    toUnit (QueryError e) = QueryError e
    toUnit (QueryResults _ n) = QueryResults [] n

searchPersons :: ConnectionPool -> Text -> IO (QueryResult [Person])
searchPersons = searchPersonsByName
