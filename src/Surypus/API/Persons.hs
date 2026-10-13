
{-# LANGUAGE OverloadedStrings #-}
-- | Surypus API Persons (Phase 1: stub)
module Surypus.API.Persons
  ( listPersons
  , createPerson
  , getPerson
  , updatePerson
  , deletePerson
  , searchPersons
  ) where

import DAL.Types (Person(..), QueryResult(..))
import Data.Int (Int64)
import Data.Text (Text)
import Database.Persist.Postgresql (ConnectionPool)

-- | List persons (stub)
listPersons :: ConnectionPool -> Maybe Text -> Maybe Text -> Maybe Int -> Maybe Int -> Maybe Int -> IO (QueryResult [Person])
listPersons _pool _ _ _ _ _ = return $ QueryResults [] 0

-- | Create person (stub)
createPerson :: Person -> IO (QueryResult Int64)
createPerson _ = return $ QuerySuccess 0

-- | Get person (stub)
getPerson :: Int64 -> IO (QueryResult Person)
getPerson _ = return $ QueryError "Not found"

-- | Update person (stub)
updatePerson :: Person -> IO (QueryResult ())
updatePerson _ = return $ QuerySuccess ()

-- | Delete person (stub)
deletePerson :: Int64 -> IO (QueryResult ())
deletePerson _ = return $ QuerySuccess ()

-- | Search persons (stub)
searchPersons :: Text -> IO (QueryResult [Person])
searchPersons _ = return $ QueryResults [] 0
