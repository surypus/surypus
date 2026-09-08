{-# LANGUAGE OverloadedStrings #-}
module Surypus.Infra.SqlGen.DSL where

-- Minimal DSL scaffold for SQL generation
import Data.List (intercalate)

newtype DSL = DSL String deriving (Show, Eq)

render :: DSL -> String
render (DSL s) = s

-- Convenience constructors
select :: String -> String -> DSL
select table column = DSL $ "SELECT " ++ column ++ " FROM " ++ table

-- DSL helpers to compose SQL statements
createTable :: String -> [(String, String)] -> DSL
createTable table cols = DSL $
  "CREATE TABLE IF NOT EXISTS " ++ table ++ " (" ++
  intercalate ", " (map (
    \(n,t) -> n ++ " " ++ t
  ) cols) ++
  ");"

multi :: [DSL] -> DSL
multi ds = DSL $ intercalate "\n" (map (\(DSL s) -> s) ds)

-- Add a column to an existing table (ALTER TABLE ... ADD COLUMN ...)
alterTableAddColumn :: String -> (String, String) -> DSL
alterTableAddColumn table (name, kind) = DSL $
  "ALTER TABLE " ++ table ++ " ADD COLUMN " ++ name ++ " " ++ kind ++ ";"

-- Drop a table if exists (helper for migrations)
dropTable :: String -> DSL
dropTable table = DSL $ "DROP TABLE IF EXISTS " ++ table ++ ";"

-- Rename a table
renameTable :: String -> String -> DSL
renameTable oldName newName = DSL $ "ALTER TABLE " ++ oldName ++ " RENAME TO " ++ newName ++ ";"

-- Add a named constraint (foreign key, check, etc.)
addConstraint :: String -> String -> String -> DSL
addConstraint table name constraint = DSL $ "ALTER TABLE " ++ table ++ " ADD CONSTRAINT " ++ name ++ " " ++ constraint ++ ";"

-- Drop a constraint by name
dropConstraint :: String -> String -> DSL
dropConstraint table constraintName = DSL $ "ALTER TABLE " ++ table ++ " DROP CONSTRAINT " ++ constraintName ++ ";"
