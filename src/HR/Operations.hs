{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module HR.Operations
  ( -- * Person CRUD
    createPerson,
    readPerson,
    updatePerson,
    deletePerson,
    listPersons,

    -- * Validation
    validatePersonData,
    checkDuplicatePerson,
    PersonValidationError   (..),

    -- * Status transitions
    activatePerson,
    deactivatePerson,
    blockPerson,
    unblockPerson,

    -- * Queries
    personsByStatus,
    personsByKind,
    findPersonByINN,
    findPersonByCode,
    countPersons,

    -- * Types
    CreatePersonRequest   (..),
    UpdatePersonRequest   (..),
    PersonOperationResult   (..),
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, getCurrentTime, utctDay)
import Data.Maybe (fromMaybe, mapMaybe)
import Data.List (find)
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)

import HR.Person
import HR.Relation

-- | Validation errors
data PersonValidationError
  = InvalidINN Text
  | InvalidKPP Text
  | InvalidPhone Text
  | InvalidEmail Text
  | InvalidName
  | InvalidCode
  | DuplicateINN Text
  | DuplicateCode Text
  | PersonNotFound Int64
  | InvalidStateTransition Text
  deriving (Show, Eq, Generic)

instance ToJSON PersonValidationError
instance FromJSON PersonValidationError

-- | Request to create a new person
data CreatePersonRequest = CreatePersonRequest
  { cprCode :: Text,
    cprName :: Text,
    cprFullName :: Maybe Text,
    cprShortName :: Maybe Text,
    cprINN :: Maybe Text,
    cprKPP :: Maybe Text,
    cprPhone :: Maybe Text,
    cprEmail :: Maybe Text,
    cprKind :: PersonKind,
    cprParentId :: Maybe Int64
  } deriving (Show, Eq, Generic)

instance FromJSON CreatePersonRequest
instance ToJSON CreatePersonRequest

-- | Request to update a person
data UpdatePersonRequest = UpdatePersonRequest
  { uprName :: Maybe Text,
    uprFullName :: Maybe Text,
    uprPhone :: Maybe Text,
    uprEmail :: Maybe Text,
    uprStatus :: Maybe PersonStatus,
    uprFlags :: Maybe PersonFlags
  } deriving (Show, Eq, Generic)

instance FromJSON UpdatePersonRequest
instance ToJSON UpdatePersonRequest

-- | Result of person operation
data PersonOperationResult a
  = OperationSuccess a
  | OperationError PersonValidationError
  | OperationConflict Text
  deriving (Show, Eq, Generic)

instance (ToJSON a) => ToJSON (PersonOperationResult a)
instance (FromJSON a) => FromJSON (PersonOperationResult a)

-- | Validation errors
validatePersonData :: CreatePersonRequest -> [PersonValidationError]
validatePersonData req = mapMaybe id
  [ if T.null (cprCode req) then Just InvalidCode else Nothing
  , if T.null (cprName req) then Just InvalidName else Nothing
  , case cprINN req of
      Just inn -> if not (validateINN inn) then Just (InvalidINN inn) else Nothing
      Nothing -> Nothing
  , case cprKPP req of
      Just kpp -> if not (validateKPP kpp) then Just (InvalidKPP kpp) else Nothing
      Nothing -> Nothing
  , case cprPhone req of
      Just phone -> if not (validatePhone phone) then Just (InvalidPhone phone) else Nothing
      Nothing -> Nothing
  , case cprEmail req of
      Just email -> if not (validateEmail email) then Just (InvalidEmail email) else Nothing
      Nothing -> Nothing
  ]

-- | Check for duplicate persons by INN
checkDuplicatePerson :: [Person] -> CreatePersonRequest -> Maybe PersonValidationError
checkDuplicatePerson persons req = do
  inn <- cprINN req
  case findPersonByINN persons inn of
    Just _ -> Just (DuplicateINN inn)
    Nothing -> case findPersonByCode persons (cprCode req) of
      Just _ -> Just (DuplicateCode (cprCode req))
      Nothing -> Nothing

-- | Create a new person
createPerson :: [Person] -> CreatePersonRequest -> Day -> PersonOperationResult Person
createPerson persons req today =
  case validatePersonData req of
    errors@(_:_) -> OperationError (head errors)
    [] -> case checkDuplicatePerson persons req of
      Just err -> OperationConflict (T.pack (show err))
      Nothing ->
        let newId = (maximum (map pId persons) `max` 0) + 1
            newPerson = Person
              { pId = newId
              , pCode = cprCode req
              , pName = cprName req
              , pFullName = fromMaybe (cprName req) (cprFullName req)
              , pShortName = fromMaybe (T.take 10 (cprName req)) (cprShortName req)
              , pINN = fromMaybe "" (cprINN req)
              , pKPP = fromMaybe "" (cprKPP req)
              , pOKPO = ""
              , pOKVED = ""
              , pLegalAddress = ""
              , pAddress = ""
              , pPhone = fromMaybe "" (cprPhone req)
              , pFax = ""
              , pEmail = fromMaybe "" (cprEmail req)
              , pWWW = ""
              , pPersonKindId = fromIntegral (fromEnum (cprKind req))
              , pCategoryId = 0
              , pStatusId = fromIntegral (fromEnum PSActive)
              , pParentId = fromMaybe 0 (cprParentId req)
              , pOwnerId = 0
              , pRegisterDate = today
              , pFlags = PersonFlags False False False False
              }
        in OperationSuccess newPerson

-- | Read person by ID
readPerson :: [Person] -> Int64 -> PersonOperationResult Person
readPerson persons pid = case find (\p -> pId p == pid) persons of
  Just p -> OperationSuccess p
  Nothing -> OperationError (PersonNotFound pid)

-- | Update person
updatePerson :: [Person] -> Int64 -> UpdatePersonRequest -> PersonOperationResult Person
updatePerson persons pid req = case readPerson persons pid of
  OperationSuccess p ->
    let updated = p
          { pName = fromMaybe (pName p) (uprName req)
          , pFullName = fromMaybe (pFullName p) (uprFullName req)
          , pPhone = fromMaybe (pPhone p) (uprPhone req)
          , pEmail = fromMaybe (pEmail p) (uprEmail req)
          , pStatusId = case uprStatus req of
              Just s -> fromIntegral (fromEnum s)
              Nothing -> pStatusId p
          , pFlags = fromMaybe (pFlags p) (uprFlags req)
          }
    in OperationSuccess updated
  err -> err

-- | Delete person (soft delete - change status)
deletePerson :: [Person] -> Int64 -> PersonOperationResult Person
deletePerson persons pid = case readPerson persons pid of
  OperationSuccess p ->
    let deleted = p { pStatusId = fromIntegral (fromEnum PSDeleted) }
    in OperationSuccess deleted
  err -> err

-- | List all persons
listPersons :: [Person] -> PersonOperationResult [Person]
listPersons persons = OperationSuccess persons

-- | Activate person
activatePerson :: Person -> PersonOperationResult Person
activatePerson p = OperationSuccess $ p
  { pStatusId = fromIntegral (fromEnum PSActive)
  , pFlags = (pFlags p) { pfLocked = False }
  }

-- | Deactivate person
deactivatePerson :: Person -> PersonOperationResult Person
deactivatePerson p = OperationSuccess $ p
  { pStatusId = fromIntegral (fromEnum PSInactive)
  }

-- | Block person
blockPerson :: Person -> PersonOperationResult Person
blockPerson p = OperationSuccess $ p
  { pStatusId = fromIntegral (fromEnum PSBlocked)
  , pFlags = (pFlags p) { pfLocked = True }
  }

-- | Unblock person
unblockPerson :: Person -> PersonOperationResult Person
unblockPerson p = OperationSuccess $ p
  { pStatusId = fromIntegral (fromEnum PSActive)
  , pFlags = (pFlags p) { pfLocked = False }
  }

-- | Query persons by status
personsByStatus :: [Person] -> PersonStatus -> [Person]
personsByStatus persons status =
  let statusId = fromIntegral (fromEnum status)
  in filter (\p -> pStatusId p == statusId) persons

-- | Query persons by kind
personsByKind :: [Person] -> PersonKind -> [Person]
personsByKind persons kind =
  let kindId = fromIntegral (fromEnum kind)
  in filter (\p -> pPersonKindId p == kindId) persons

-- | Find person by INN
findPersonByINN :: [Person] -> Text -> Maybe Person
findPersonByINN persons inn =
  case [p | p <- persons, pINN p == inn, pINN p /= ""] of
    [] -> Nothing
    (p:_) -> Just p

-- | Find person by code
findPersonByCode :: [Person] -> Text -> Maybe Person
findPersonByCode persons code =
  case [p | p <- persons, pCode p == code] of
    [] -> Nothing
    (p:_) -> Just p

-- | Count total persons
countPersons :: [Person] -> Int
countPersons = length

-- | Count active persons
countActivePersons :: [Person] -> Int
countActivePersons persons = length (personsByStatus persons PSActive)

-- | Count by kind
countByKind :: [Person] -> PersonKind -> Int
countByKind persons kind = length (personsByKind persons kind)
