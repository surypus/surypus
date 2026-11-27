{-# LANGUAGE OverloadedStrings #-}

module DAL.RBACRepositorySpec (spec) where

import Control.Exception (ioError)
import System.IO.Error (userError)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Sql (PersistValue (..), Single (..))
import DAL.Repository.RBAC (checkPermissionWith, permissionSql, splitPermission)
import Test.Hspec

runner :: [Single Bool] -> Text -> [PersistValue] -> IO [Single Bool]
runner result _ _ = pure result

capturing :: IORef [(Text, [PersistValue])] -> [Single Bool] -> Text -> [PersistValue] -> IO [Single Bool]
capturing ref result query params = do
  modifyIORef' ref ((query, params) :)
  pure result

spec :: Spec
spec = describe "RBAC repository (fail-closed)" $ do
  describe "splitPermission" $ do
    it "accepts action:resource" $
      splitPermission "read:persons" `shouldBe` Just ("read", "persons")

    it "maps create to the seeded write action" $
      splitPermission "create:persons" `shouldBe` Just ("write", "persons")

    it "rejects wildcards" $ do
      splitPermission "*" `shouldBe` Nothing
      splitPermission "read:*" `shouldBe` Nothing
      splitPermission "*:persons" `shouldBe` Nothing

    it "rejects malformed strings" $ do
      splitPermission "read" `shouldBe` Nothing
      splitPermission "a:b:c" `shouldBe` Nothing
      splitPermission "" `shouldBe` Nothing

  describe "permissionSql" $ do
    it "binds both values as parameters" $
      T.count "?" permissionSql `shouldBe` 2

    it "does not embed a permission name or a literal user id" $ do
      T.isInfixOf "persons" permissionSql `shouldBe` False
      T.isInfixOf "user_id = 7" permissionSql `shouldBe` False

  describe "checkPermissionWith" $ do
    it "grants when the query returns true" $
      checkPermissionWith (runner [Single True]) 7 "read:persons" `shouldReturn` True

    it "denies when the query returns false" $
      checkPermissionWith (runner [Single False]) 7 "read:persons" `shouldReturn` False

    it "denies on an empty result" $
      checkPermissionWith (runner []) 7 "read:persons" `shouldReturn` False

    it "denies when the query throws" $
      checkPermissionWith (\_ _ -> ioError (userError "db down")) 7 "read:persons"
        `shouldReturn` False

    it "denies malformed permissions without querying" $ do
      calls <- newIORef []
      result <- checkPermissionWith (capturing calls [Single True]) 7 "read:*"
      result `shouldBe` False
      readIORef calls `shouldReturn` []

    it "passes the user id and normalised permission as bound parameters" $ do
      calls <- newIORef []
      _ <- checkPermissionWith (capturing calls [Single True]) 7 "create:persons"
      params <- fmap (map snd) (readIORef calls)
      params `shouldBe` [[PersistInt64 7, PersistText "write:persons"]]

    it "passes hostile input as data, never as SQL" $ do
      calls <- newIORef []
      _ <- checkPermissionWith (capturing calls [Single False]) 7 "read:persons' OR true--"
      params <- fmap (map snd) (readIORef calls)
      params
        `shouldBe` [ [ PersistInt64 7,
                       PersistText "read:persons' OR true--"
                     ]
                   ]
