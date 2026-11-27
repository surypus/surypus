{-# LANGUAGE OverloadedStrings #-}

-- | Regression coverage for the P0 defect where runDb used rawExecute on a
-- SELECT statement, making every tenant-scoped query fail.
module DAL.TenantScopedDbSpec (spec) where

import Control.Exception (bracket)
import Control.Monad.Logger (runNoLoggingT)
import qualified Data.ByteString.Char8 as BC
import qualified Data.Text as Data.Text
import DAL.Database (withTenantContext)
import qualified DAL.Database as DB
import qualified DAL.Pool as Pool
import Database.Persist.Postgresql (createPostgresqlPool)
import Database.Persist.Sql (PersistValue (..), Single (..), SqlPersistT, rawSql, runSqlPool)
import System.Environment (lookupEnv)
import Test.Hspec

readSetting :: Pool.ConnectionPool -> String -> IO [Single String]
readSetting pool name =
  Pool.runDb pool
    (rawSql "SELECT current_setting(?)" [PersistText (Data.Text.pack name)] :: SqlPersistT IO [Single String])

spec :: Spec
spec = do
  mUrl <- runIO (lookupEnv "SURYPUS_TEST_DATABASE_URL")
  case mUrl of
    Nothing ->
      it "requires SURYPUS_TEST_DATABASE_URL" $
        pendingWith "set SURYPUS_TEST_DATABASE_URL to exercise tenant-scoped SQL"
    Just url ->
      describe "tenant-scoped runDb (live PostgreSQL)" $ do
        it "sets tenant and user context inside withTenantContext" $
          bracket
            (runNoLoggingT (createPostgresqlPool (BC.pack url) 2))
            Pool.closePool
            ( \pool -> do
                values <- withTenantContext 42 7 $ do
                  tenant <- readSetting pool "app.tenant_id"
                  user <- readSetting pool "app.user_id"
                  pure (tenant, user)
                fmap (\(Single v) -> v) (fst values) `shouldBe` ["42"]
                fmap (\(Single v) -> v) (snd values) `shouldBe` ["7"]
            )

        it "sets context through runDbWithTenant" $
          bracket
            (runNoLoggingT (createPostgresqlPool (BC.pack url) 2))
            Pool.closePool
            ( \pool -> do
                rows <- DB.runDbWithTenant 99 88 pool (rawSql "SELECT current_setting('app.tenant_id')" [] :: SqlPersistT IO [Single String])
                fmap (\(Single v) -> v) rows `shouldBe` ["99"]
            )
