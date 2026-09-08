{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- | DAL Procedures - Stored procedures and function calls
module DAL.Procedures
  ( runProcedure
  , callFunction
  , runRawSql
  , executeSql
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import DAL.Types
import DAL.Database (ConnectionPool, runDb)
import Database.Persist.Sql
  ( rawSql
  , rawExecute
  , PersistValue(..)
  , Single(..)
  , Entity(..)
  , PersistEntity(..)
  , PersistInt64
  , fromSqlKey
  , toSqlKey
  )

-- | Run a stored procedure and return results
-- Example: runProcedure pool "calculate_balance" ["account_id"]
runProcedure :: ConnectionPool -> Text -> [PersistValue] -> IO (CommandResult [PersistValue])
runProcedure pool procName params = do
  let sql = "CALL " <> T.unpack procName <> "(" <> paramsPlaceholder (length params) <> ")"
  result <- runDb pool $ rawExecute sql params
  return $ CommandSuccess [PersistInt64 (fromIntegral result)]

-- | Call a database function and return the result
callFunction :: ConnectionPool -> Text -> [PersistValue] -> IO (CommandResult PersistValue)
callFunction pool funcName params = do
  let sql = "SELECT " <> T.unpack funcName <> "(" <> paramsPlaceholder (length params) <> ")"
  result <- runDb pool $ rawSql sql params :: IO [Single PersistValue]
  case result of
    (Single v : _) -> return $ CommandSuccess v
    _ -> return $ CommandSuccess PersistNull

-- | Execute raw SQL and return entity results
runRawSql :: (PersistEntity a) => ConnectionPool -> Text -> [PersistValue] -> IO (CommandResult [Entity a])
runRawSql pool sql params = do
  result <- runDb pool $ rawSql sql params
  return $ CommandSuccess result

-- | Execute raw SQL without results
executeSql :: ConnectionPool -> Text -> [PersistValue] -> IO (CommandResult Int64)
executeSql pool sql params = do
  result <- runDb pool $ rawExecute sql params
  return $ CommandSuccess (fromIntegral result)

-- | Create placeholder string (?, ?, ?)
paramsPlaceholder :: Int -> String
paramsPlaceholder n = T.unpack $ T.intercalate ", " $ replicate n "?"
