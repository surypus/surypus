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

-- | List persons (stub)
listPersons :: Int64 -> Maybe Text -> Maybe Text -> Maybe Int -> Maybe Int -> Maybe Int -> IO (QueryResult [Person])
listPersons _ _ _ _ _ _ = return $ QueryResult [] 0

-- | Create person (stub)
createPerson :: Person -> IO (QueryResult Int64)
createPerson _ = return $ QueryResult [0] 1

-- | Get person (stub)
getPerson :: Int64 -> IO (QueryResult Person)
getPerson _ = return $ QueryResult [] 0

-- | Update person (stub)
updatePerson :: Person -> IO (QueryResult ())
updatePerson _ = return $ QueryResult [()] 1

-- | Delete person (stub)
deletePerson :: Int64 -> IO (QueryResult ())
deletePerson _ = return $ QueryResult [()] 1

-- | Search persons (stub)
searchPersons :: Text -> IO (QueryResult [Person])
searchPersons _ = return $ QueryResult [] 0
