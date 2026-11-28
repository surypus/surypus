{-# LANGUAGE OverloadedStrings #-}

-- | The migration order must be deterministic and shared by all runners.
module MigrationCorpusSpec (spec) where

import Data.List (isInfixOf)
import System.Directory (listDirectory)
import System.Process (readProcess)
import Test.Hspec

migrationFiles :: IO [FilePath]
migrationFiles = lines <$> readProcess "bash" ["scripts/migration-files.sh"] ""

canonicalCount :: IO Int
canonicalCount = do
  let dirs = ["sql/migrations", "sql/event", "sql/projection", "sql/aggregate"]
  counts <- mapM (fmap (length . filter isMigration) . listDirectory) dirs
  pure $ sum counts
  where
    isMigration name = take 1 name == "V" && takeEnd 4 name == ".sql"
    takeEnd n xs = drop (length xs - n) xs

spec :: Spec
spec = describe "migration corpus" $ do
  it "emits a deterministic order" $ do
    first <- migrationFiles
    second <- migrationFiles
    first `shouldBe` second

  it "includes every canonical V*.sql file exactly once" $ do
    files <- migrationFiles
    expected <- canonicalCount
    length files `shouldBe` expected

  it "puts the core schema before tenant scoping" $ do
    files <- migrationFiles
    let core = "sql/migrations/V001__core_schema.sql"
        tenant = "sql/migrations/V001b__tenant_scoping.sql"
    maybe (-1) id (indexOf core files) `shouldBeLessThan` maybe maxBound id (indexOf tenant files)

  it "excludes legacy and fixture directories" $ do
    files <- migrationFiles
    filter ("sql/core/" `isInfixOf`) files `shouldBe` []
    filter ("sql/test/" `isInfixOf`) files `shouldBe` []
    filter ("sql/archive/" `isInfixOf`) files `shouldBe` []

  it "makes both CI scripts use the shared list" $ do
    runner <- readFile "scripts/migrate.sh"
    dryRun <- readFile "scripts/ci-dry-run-mig.sh"
    runner `shouldSatisfy` isInfixOf "scripts/migration-files.sh"
    dryRun `shouldSatisfy` isInfixOf "scripts/migration-files.sh"
    dryRun `shouldSatisfy` not . isInfixOf "V*.generated.sql"

indexOf :: Eq a => a -> [a] -> Maybe Int
indexOf needle = go 0
  where
    go _ [] = Nothing
    go n (x : xs)
      | x == needle = Just n
      | otherwise = go (n + 1) xs

shouldBeLessThan :: (Ord a, Show a) => a -> a -> Expectation
shouldBeLessThan a b = (a < b) `shouldBe` True
