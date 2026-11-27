{-# LANGUAGE OverloadedStrings #-}

module DAL.ConnectionConfigSpec (spec) where

import Data.List (isInfixOf)

import DAL.Database (buildConnectionString)
import Test.Hspec

spec :: Spec
spec = do
  describe "connection configuration" $ do
    it "has no hardcoded connection strings in ORM pool" $ do
      source <- readFile "src/DAL/ORMPool.hs"
      source `shouldSatisfy` not . isInfixOf "host=localhost port=5432"
      source `shouldSatisfy` isInfixOf "DAL.Database.createPool"
  describe "buildConnectionString (fail-fast config)" $ do
    it "builds a connection string from validated parts" $
      buildConnectionString "db.local" "5432" "surypus" "app" "secret"
        `shouldBe` Right "host=db.local port=5432 dbname=surypus user=app password=secret"

    it "rejects an empty host" $
      buildConnectionString "" "5432" "surypus" "app" "secret"
        `shouldBe` Left "DB_HOST must not be empty"

    it "rejects an empty user" $
      buildConnectionString "db.local" "5432" "surypus" "" "secret"
        `shouldBe` Left "DB_USER must not be empty"

    it "rejects whitespace that could inject connection parameters" $
      buildConnectionString "host=evil port=1" "5432" "surypus" "app" "secret"
        `shouldBe` Left "DB_HOST contains an invalid character"

    it "rejects quotes" $
      buildConnectionString "db.local" "5432" "surypus" "app'x" "secret"
        `shouldBe` Left "DB_USER contains an invalid character"
