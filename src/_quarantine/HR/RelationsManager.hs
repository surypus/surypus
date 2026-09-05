{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module HR.RelationsManager
  ( -- * Types
    RelationType   (..),
    RelationStatus   (..),
    CreateRelationRequest   (..),
    RelationOperationResult   (..),

    -- * Operations
    createRelation,
    readRelation,
    endRelation,
    listRelations,

    -- * Queries
    subordinates,
    managers,
    colleagues,
    organizationalHierarchy,

    -- * Validation
    validateRelation,
    RelationValidationError   (..),
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import Data.Maybe (mapMaybe)
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)

import HR.Person (Person, pId)

-- | Relation type
data RelationType
  = Manager
  | Subordinate
  | Colleague
  | Mentor
  | Peer
  | Parent
  | Child
  deriving (Show, Eq, Enum, Generic)

instance ToJSON RelationType
instance FromJSON RelationType

-- | Relation status
data RelationStatus
  = RelationActive
  | RelationInactive
  | RelationEnded
  deriving (Show, Eq, Enum, Generic)

instance ToJSON RelationStatus
instance FromJSON RelationStatus

-- | Person relation
data PersonRelation = PersonRelation
  { relId :: Int64,
    relFromPersonId :: Int64,
    relToPersonId :: Int64,
    relType :: RelationType,
    relStatus :: RelationStatus,
    relStartDate :: Day,
    relEndDate :: Maybe Day,
    relDescription :: Maybe Text
  } deriving (Show, Eq, Generic)

instance ToJSON PersonRelation
instance FromJSON PersonRelation

-- | Request to create relation
data CreateRelationRequest = CreateRelationRequest
  { crFromPersonId :: Int64,
    crToPersonId :: Int64,
    crRelationType :: RelationType,
    crStartDate :: Day,
    crDescription :: Maybe Text
  } deriving (Show, Eq, Generic)

instance ToJSON CreateRelationRequest
instance FromJSON CreateRelationRequest

-- | Validation errors
data RelationValidationError
  = SamePersonRelation
  | PersonNotFound
  | RelationNotFound
  | InvalidRelationType
  | InvalidDateRange
  deriving (Show, Eq, Generic)

instance ToJSON RelationValidationError
instance FromJSON RelationValidationError

-- | Operation result
data RelationOperationResult a
  = RelationSuccess a
  | RelationError RelationValidationError
  deriving (Show, Eq, Generic)

instance (ToJSON a) => ToJSON (RelationOperationResult a)
instance (FromJSON a) => FromJSON (RelationOperationResult a)

-- | Validate relation creation
validateRelation :: [Person] -> CreateRelationRequest -> Maybe RelationValidationError
validateRelation persons req
  | crFromPersonId req == crToPersonId req = Just SamePersonRelation
  | not (any (\p -> pId p == crFromPersonId req) persons) = Just PersonNotFound
  | not (any (\p -> pId p == crToPersonId req) persons) = Just PersonNotFound
  | otherwise = Nothing

-- | Create a new relation
createRelation :: [PersonRelation] -> [Person] -> CreateRelationRequest -> RelationOperationResult PersonRelation
createRelation relations persons req = case validateRelation persons req of
  Just err -> RelationError err
  Nothing ->
    let newId = (maximum (map relId relations) `max` 0) + 1
        newRelation = PersonRelation
          { relId = newId
          , relFromPersonId = crFromPersonId req
          , relToPersonId = crToPersonId req
          , relType = crRelationType req
          , relStatus = RelationActive
          , relStartDate = crStartDate req
          , relEndDate = Nothing
          , relDescription = crDescription req
          }
    in RelationSuccess newRelation

-- | Read relation by ID
readRelation :: [PersonRelation] -> Int64 -> RelationOperationResult PersonRelation
readRelation relations rid = case [r | r <- relations, relId r == rid] of
  [] -> RelationError RelationNotFound
  (r:_) -> RelationSuccess r

-- | End a relation
endRelation :: [PersonRelation] -> Int64 -> Day -> RelationOperationResult PersonRelation
endRelation relations rid endDate = case readRelation relations rid of
  RelationSuccess r ->
    let ended = r
          { relStatus = RelationEnded
          , relEndDate = Just endDate
          }
    in RelationSuccess ended
  err -> err

-- | List all relations
listRelations :: [PersonRelation] -> RelationOperationResult [PersonRelation]
listRelations rels = RelationSuccess rels

-- | Get subordinates of a person
subordinates :: [PersonRelation] -> Int64 -> [Int64]
subordinates relations personId =
  mapMaybe (\r ->
    if relFromPersonId r == personId &&
       relType r == Manager &&
       relStatus r == RelationActive
    then Just (relToPersonId r)
    else Nothing) relations

-- | Get managers of a person
managers :: [PersonRelation] -> Int64 -> [Int64]
managers relations personId =
  mapMaybe (\r ->
    if relToPersonId r == personId &&
       relType r == Manager &&
       relStatus r == RelationActive
    then Just (relFromPersonId r)
    else Nothing) relations

-- | Get colleagues of a person
colleagues :: [PersonRelation] -> Int64 -> [Int64]
colleagues relations personId =
  mapMaybe (\r ->
    if (relFromPersonId r == personId || relToPersonId r == personId) &&
       relType r == Colleague &&
       relStatus r == RelationActive
    then if relFromPersonId r == personId
         then Just (relToPersonId r)
         else Just (relFromPersonId r)
    else Nothing) relations

-- | Get organizational hierarchy (recursive)
-- Returns all subordinates directly and indirectly under a manager
organizationalHierarchy :: [PersonRelation] -> Int64 -> [Int64]
organizationalHierarchy relations personId =
  let direct = subordinates relations personId
      indirect = concatMap (organizationalHierarchy relations) direct
  in direct ++ indirect

-- | Validate organizational hierarchy (no cycles)
validateHierarchyNoCycles :: [PersonRelation] -> Bool
validateHierarchyNoCycles relations =
  all (\r -> not (hasCycle (relFromPersonId r) (relToPersonId r) relations)) relations
  where
    hasCycle :: Int64 -> Int64 -> [PersonRelation] -> Bool
    hasCycle from to rels = to `elem` organizationalHierarchy rels from

-- | Count relations of a type for a person
countRelationsByType :: [PersonRelation] -> Int64 -> RelationType -> Int
countRelationsByType relations personId targetRelType =
  length $ filter (\r ->
    (relFromPersonId r == personId || relToPersonId r == personId) &&
    relType r == targetRelType &&
    relStatus r == RelationActive) relations

-- | Get all active relations for a person
activeRelationsForPerson :: [PersonRelation] -> Int64 -> [PersonRelation]
activeRelationsForPerson relations personId =
  filter (\r ->
    (relFromPersonId r == personId || relToPersonId r == personId) &&
    relStatus r == RelationActive) relations
