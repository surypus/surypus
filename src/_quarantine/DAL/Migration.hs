{-# LANGUAGE OverloadedStrings #-}

module DAL.Migration
  ( runMigrations
  , runMigrationsQuiet
  , migrateAll
  ) where

import Data.Text (Text)
import Database.Persist.Sql (SqlPersistT, runMigrationQuiet, runMigration)

migrateAll :: SqlPersistT IO ()
migrateAll = return ()

runMigrations :: SqlPersistT IO ()
runMigrations = runMigration migrateAll

runMigrationsQuiet :: SqlPersistT IO [Text]
runMigrationsQuiet = runMigrationQuiet migrateAll
