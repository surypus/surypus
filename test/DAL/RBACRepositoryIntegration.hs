{-# LANGUAGE OverloadedStrings #-}

-- | Real PostgreSQL coverage for the DB-backed permission check.
module DAL.RBACRepositoryIntegration (spec) where

import Control.Exception (finally)
import Control.Monad.Logger (runNoLoggingT)
import qualified Data.ByteString.Char8 as BC
import qualified Data.Text as T
import DAL.Pool (closePool)
import DAL.Repository.RBAC (checkUserAppPermissionRepo, mkRBACRepository)
import Database.Persist.Postgresql (ConnectionPool, createPostgresqlPool)
import Database.Persist.Sql (PersistValue (..), rawExecute, runSqlPool)
import System.Environment (lookupEnv)
import Test.Hspec

insertUser :: ConnectionPool -> Int -> T.Text -> IO ()
insertUser pool uid name =
  runSqlPool
    ( rawExecute
        "INSERT INTO users (id, username, password_hash, tenant_id) VALUES (?, ?, 'x', 0) ON CONFLICT (id) DO NOTHING"
        [PersistInt64 (fromIntegral uid), PersistText name]
    )
    pool

grantRole :: ConnectionPool -> Int -> T.Text -> IO ()
grantRole pool uid role =
  runSqlPool
    ( rawExecute
        "INSERT INTO user_role (user_id, role_id) SELECT ?, id FROM role WHERE name = ? ON CONFLICT DO NOTHING"
        [PersistInt64 (fromIntegral uid), PersistText role]
    )
    pool

cleanup :: ConnectionPool -> IO ()
cleanup pool = do
  runSqlPool (rawExecute "DELETE FROM user_role WHERE user_id IN (999002, 999003)" []) pool
  runSqlPool (rawExecute "DELETE FROM users WHERE id IN (999002, 999003)" []) pool

spec :: Spec
spec = do
  mUrl <- runIO (lookupEnv "SURYPUS_TEST_DATABASE_URL")
  case mUrl of
    Nothing ->
      it "requires SURYPUS_TEST_DATABASE_URL" $
        pendingWith "set SURYPUS_TEST_DATABASE_URL to a migrated PostgreSQL database"
    Just url ->
      beforeAll (runNoLoggingT (createPostgresqlPool (BC.pack url) 2)) $
        afterAll closePool $
          describe "checkUserAppPermissionRepo (live PostgreSQL)" $ do
            it "allows a granted permission and denies an ungranted one" $ \pool -> do
              let repo = mkRBACRepository pool
              _ <- insertUser pool 999002 "rbac_probe_viewer"
              _ <- grantRole pool 999002 "viewer"
              finally
                (do
                   allowed <- checkUserAppPermissionRepo repo 999002 "read:persons"
                   denied <- checkUserAppPermissionRepo repo 999002 "delete:persons"
                   allowed `shouldBe` True
                   denied `shouldBe` False
                )
                (cleanup pool)

            it "denies a user with no role" $ \pool -> do
              let repo = mkRBACRepository pool
              result <- checkUserAppPermissionRepo repo 999999 "read:persons"
              result `shouldBe` False

            it "allows any permission for the admin role" $ \pool -> do
              let repo = mkRBACRepository pool
              _ <- insertUser pool 999003 "rbac_probe_admin"
              _ <- grantRole pool 999003 "admin"
              finally
                (do
                   result <- checkUserAppPermissionRepo repo 999003 "delete:persons"
                   result `shouldBe` True
                )
                (cleanup pool)
