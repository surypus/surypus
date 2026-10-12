{-# LANGUAGE OverloadedStrings #-}

module HR.OperationsSpec (spec) where

import Test.Hspec
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (fromGregorian)

import HR.Person
import HR.Operations

spec :: Spec
spec = do
  describe "HR.Operations - Person CRUD and Validation" $ do

    -- Validation tests
    describe "Person data validation" $ do
      it "should validate a valid create request" $ do
        let req = CreatePersonRequest
              { cprCode = "C001"
              , cprName = "Test Company"
              , cprFullName = Just "Test Company Full"
              , cprShortName = Just "TC"
              , cprINN = Just "1234567890"
              , cprKPP = Just "123456789"
              , cprPhone = Just "+7-999-123-45-67"
              , cprEmail = Just "test@company.com"
              , cprKind = PKCompany
              , cprParentId = Nothing
              }
        validatePersonData req `shouldBe` []

      it "should reject empty code" $ do
        let req = CreatePersonRequest
              { cprCode = ""
              , cprName = "Test"
              , cprFullName = Nothing
              , cprShortName = Nothing
              , cprINN = Nothing
              , cprKPP = Nothing
              , cprPhone = Nothing
              , cprEmail = Nothing
              , cprKind = PKCompany
              , cprParentId = Nothing
              }
        validatePersonData req `shouldContain` [InvalidCode]

      it "should reject empty name" $ do
        let req = CreatePersonRequest
              { cprCode = "C001"
              , cprName = ""
              , cprFullName = Nothing
              , cprShortName = Nothing
              , cprINN = Nothing
              , cprKPP = Nothing
              , cprPhone = Nothing
              , cprEmail = Nothing
              , cprKind = PKCompany
              , cprParentId = Nothing
              }
        validatePersonData req `shouldContain` [InvalidName]

      it "should reject invalid INN" $ do
        let req = CreatePersonRequest
              { cprCode = "C001"
              , cprName = "Test"
              , cprFullName = Nothing
              , cprShortName = Nothing
              , cprINN = Just "invalid"
              , cprKPP = Nothing
              , cprPhone = Nothing
              , cprEmail = Nothing
              , cprKind = PKCompany
              , cprParentId = Nothing
              }
        validatePersonData req `shouldContain` [InvalidINN "invalid"]

      it "should reject invalid KPP" $ do
        let req = CreatePersonRequest
              { cprCode = "C001"
              , cprName = "Test"
              , cprFullName = Nothing
              , cprShortName = Nothing
              , cprINN = Nothing
              , cprKPP = Just "invalid"
              , cprPhone = Nothing
              , cprEmail = Nothing
              , cprKind = PKCompany
              , cprParentId = Nothing
              }
        validatePersonData req `shouldContain` [InvalidKPP "invalid"]

    -- Person creation tests
    describe "Person CRUD operations" $ do
      it "should create a valid person" $ do
        let req = CreatePersonRequest
              { cprCode = "P001"
              , cprName = "Company A"
              , cprFullName = Just "Company A Limited"
              , cprShortName = Nothing
              , cprINN = Just "1234567890"
              , cprKPP = Just "123456789"
              , cprPhone = Nothing
              , cprEmail = Nothing
              , cprKind = PKCompany
              , cprParentId = Nothing
              }
            today = fromGregorian 2024 1 1
            result = createPerson [] req today
        case result of
          OperationSuccess p -> do
            pCode p `shouldBe` "P001"
            pName p `shouldBe` "Company A"
          _ -> fail "Expected success"

      it "should reject duplicate INN" $ do
        let person = Person
              { pId = 1
              , pCode = "P001"
              , pName = "Existing"
              , pFullName = "Existing Company"
              , pShortName = "EC"
              , pINN = "1234567890"
              , pKPP = "123456789"
              , pOKPO = ""
              , pOKVED = ""
              , pLegalAddress = ""
              , pAddress = ""
              , pPhone = ""
              , pFax = ""
              , pEmail = ""
              , pWWW = ""
              , pPersonKindId = 1
              , pCategoryId = 0
              , pStatusId = 0
              , pParentId = 0
              , pOwnerId = 0
              , pRegisterDate = fromGregorian 2024 1 1
              , pFlags = PersonFlags False False False False
              }
            req = CreatePersonRequest
              { cprCode = "P002"
              , cprName = "Company B"
              , cprFullName = Nothing
              , cprShortName = Nothing
              , cprINN = Just "1234567890"
              , cprKPP = Nothing
              , cprPhone = Nothing
              , cprEmail = Nothing
              , cprKind = PKCompany
              , cprParentId = Nothing
              }
            today = fromGregorian 2024 1 1
            result = createPerson [person] req today
        case result of
          OperationConflict _ -> (pure () :: IO ())
          _ -> fail "Expected conflict"

      it "should find person by INN" $ do
        let person = Person
              { pId = 1
              , pCode = "P001"
              , pName = "Company"
              , pFullName = "Company Full"
              , pShortName = "CF"
              , pINN = "1234567890"
              , pKPP = "123456789"
              , pOKPO = ""
              , pOKVED = ""
              , pLegalAddress = ""
              , pAddress = ""
              , pPhone = ""
              , pFax = ""
              , pEmail = ""
              , pWWW = ""
              , pPersonKindId = 1
              , pCategoryId = 0
              , pStatusId = 0
              , pParentId = 0
              , pOwnerId = 0
              , pRegisterDate = fromGregorian 2024 1 1
              , pFlags = PersonFlags False False False False
              }
        findPersonByINN [person] "1234567890" `shouldBe` Just person

      it "should find person by code" $ do
        let person = Person
              { pId = 1
              , pCode = "P001"
              , pName = "Company"
              , pFullName = "Company Full"
              , pShortName = "CF"
              , pINN = "1234567890"
              , pKPP = "123456789"
              , pOKPO = ""
              , pOKVED = ""
              , pLegalAddress = ""
              , pAddress = ""
              , pPhone = ""
              , pFax = ""
              , pEmail = ""
              , pWWW = ""
              , pPersonKindId = 1
              , pCategoryId = 0
              , pStatusId = 0
              , pParentId = 0
              , pOwnerId = 0
              , pRegisterDate = fromGregorian 2024 1 1
              , pFlags = PersonFlags False False False False
              }
        findPersonByCode [person] "P001" `shouldBe` Just person

    -- Status transitions
    describe "Person status transitions" $ do
      it "should activate a person" $ do
        let person = Person
              { pId = 1
              , pCode = "P001"
              , pName = "Company"
              , pFullName = "Company Full"
              , pShortName = "CF"
              , pINN = "1234567890"
              , pKPP = "123456789"
              , pOKPO = ""
              , pOKVED = ""
              , pLegalAddress = ""
              , pAddress = ""
              , pPhone = ""
              , pFax = ""
              , pEmail = ""
              , pWWW = ""
              , pPersonKindId = 1
              , pCategoryId = 0
              , pStatusId = 2
              , pParentId = 0
              , pOwnerId = 0
              , pRegisterDate = fromGregorian 2024 1 1
              , pFlags = PersonFlags False False False False
              }
        case activatePerson person of
          OperationSuccess p ->
            pStatusId p `shouldBe` fromIntegral (fromEnum PSActive)
          _ -> fail "Expected success"

      it "should deactivate a person" $ do
        let person = Person
              { pId = 1
              , pCode = "P001"
              , pName = "Company"
              , pFullName = "Company Full"
              , pShortName = "CF"
              , pINN = "1234567890"
              , pKPP = "123456789"
              , pOKPO = ""
              , pOKVED = ""
              , pLegalAddress = ""
              , pAddress = ""
              , pPhone = ""
              , pFax = ""
              , pEmail = ""
              , pWWW = ""
              , pPersonKindId = 1
              , pCategoryId = 0
              , pStatusId = 0
              , pParentId = 0
              , pOwnerId = 0
              , pRegisterDate = fromGregorian 2024 1 1
              , pFlags = PersonFlags False False False False
              }
        case deactivatePerson person of
          OperationSuccess p ->
            pStatusId p `shouldBe` fromIntegral (fromEnum PSInactive)
          _ -> fail "Expected success"

      it "should block a person" $ do
        let person = Person
              { pId = 1
              , pCode = "P001"
              , pName = "Company"
              , pFullName = "Company Full"
              , pShortName = "CF"
              , pINN = "1234567890"
              , pKPP = "123456789"
              , pOKPO = ""
              , pOKVED = ""
              , pLegalAddress = ""
              , pAddress = ""
              , pPhone = ""
              , pFax = ""
              , pEmail = ""
              , pWWW = ""
              , pPersonKindId = 1
              , pCategoryId = 0
              , pStatusId = 0
              , pParentId = 0
              , pOwnerId = 0
              , pRegisterDate = fromGregorian 2024 1 1
              , pFlags = PersonFlags False False False False
              }
        case blockPerson person of
          OperationSuccess p -> do
            pStatusId p `shouldBe` fromIntegral (fromEnum PSBlocked)
            pfLocked (pFlags p) `shouldBe` True
          _ -> fail "Expected success"

    -- Query operations
    describe "Person query operations" $ do
      it "should count persons" $ do
        let persons = replicate 5 (Person
              { pId = 0
              , pCode = "P001"
              , pName = "Company"
              , pFullName = "Company Full"
              , pShortName = "CF"
              , pINN = "1234567890"
              , pKPP = "123456789"
              , pOKPO = ""
              , pOKVED = ""
              , pLegalAddress = ""
              , pAddress = ""
              , pPhone = ""
              , pFax = ""
              , pEmail = ""
              , pWWW = ""
              , pPersonKindId = 1
              , pCategoryId = 0
              , pStatusId = 0
              , pParentId = 0
              , pOwnerId = 0
              , pRegisterDate = fromGregorian 2024 1 1
              , pFlags = PersonFlags False False False False
              })
        countPersons persons `shouldBe` 5

      it "should filter by kind" $ do
        let person1 = Person
              { pId = 1
              , pCode = "P001"
              , pName = "Company"
              , pFullName = "Company Full"
              , pShortName = "CF"
              , pINN = "1234567890"
              , pKPP = "123456789"
              , pOKPO = ""
              , pOKVED = ""
              , pLegalAddress = ""
              , pAddress = ""
              , pPhone = ""
              , pFax = ""
              , pEmail = ""
              , pWWW = ""
              , pPersonKindId = fromIntegral (fromEnum PKCompany)
              , pCategoryId = 0
              , pStatusId = 0
              , pParentId = 0
              , pOwnerId = 0
              , pRegisterDate = fromGregorian 2024 1 1
              , pFlags = PersonFlags False False False False
              }
            person2 = person1 { pId = 2, pPersonKindId = fromIntegral (fromEnum PKIndividual) }
        length (personsByKind [person1, person2] PKCompany) `shouldBe` 1
