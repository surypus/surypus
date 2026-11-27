{-# LANGUAGE OverloadedStrings #-}
module DAL.Database (
    Pool,
    createPool,
    createPoolWith,
    createPoolFromEnv,
    buildConnectionString,
    closePool,
    ConnectionPool,
    runDb,
    runDbWithTenant,
    currentTenantContext,
    setCurrentTenantContext,
    withTenantContext,
    clearCurrentTenantContext,
) where

import Data.Int (Int64)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Control.Concurrent (ThreadId, myThreadId)
import Control.Exception (finally)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Postgresql (ConnectionPool, createPostgresqlPool)
import Database.Persist.Sql (SqlPersistT, runSqlPool, PersistValue(..), rawExecute, rawSql, Single(..))
import Control.Monad.Logger (runNoLoggingT)
import Data.ByteString.Char8 (pack)
import Data.Pool (destroyAllResources)
import System.IO.Unsafe (unsafePerformIO)
import System.Environment (lookupEnv)
import Data.Maybe (fromMaybe)
import System.IO.Error (userError)
import Data.Char (isSpace)

type Pool = ConnectionPool

-- | Per-thread tenant context, keyed by 'ThreadId'.
--
-- A single global IORef leaked tenant A's context into tenant B's queries
-- whenever two requests ran concurrently. Each WAI request runs in its own
-- thread, so keying by ThreadId makes the context request-scoped.
{-# NOINLINE tenantContextVar #-}
tenantContextVar :: IORef (Map.Map ThreadId (Int64, Int64))
tenantContextVar = unsafePerformIO $ newIORef Map.empty

currentTenantContext :: IO (Maybe (Int64, Int64))
currentTenantContext = do
  tid <- myThreadId
  Map.lookup tid <$> readIORef tenantContextVar

setCurrentTenantContext :: Int64 -> Int64 -> IO ()
setCurrentTenantContext tenantId userId = do
  tid <- myThreadId
  modifyIORef' tenantContextVar (Map.insert tid (tenantId, userId))

clearCurrentTenantContext :: IO ()
clearCurrentTenantContext = do
  tid <- myThreadId
  modifyIORef' tenantContextVar (Map.delete tid)

-- | Scope a tenant context to an action and restore the previous value on exit.
withTenantContext :: Int64 -> Int64 -> IO a -> IO a
withTenantContext tenantId userId action = do
  tid <- myThreadId
  previous <- Map.lookup tid <$> readIORef tenantContextVar
  setCurrentTenantContext tenantId userId
  let restore = case previous of
        Just (oldTenant, oldUser) -> setCurrentTenantContext oldTenant oldUser
        Nothing -> clearCurrentTenantContext
  action `finally` restore

-- | Backwards-compatible pool constructor.
createPool :: IO ConnectionPool
createPool = do
  password <- maybe "" id <$> lookupEnv "DB_PASSWORD"
  case buildConnectionString "localhost" "5432" "surypus" "postgres" password of
    Left err -> ioError (userError err)
    Right connStr -> createPoolWith connStr 10

-- | Create a pool from an explicit connection string.
createPoolWith :: String -> Int -> IO ConnectionPool
createPoolWith connStr stripes = runNoLoggingT $ createPostgresqlPool (pack connStr) stripes

-- | Build a libpq connection string. Every component is validated so a value
-- from the environment cannot inject extra connection parameters.
buildConnectionString :: String -> String -> String -> String -> String -> Either String String
buildConnectionString host port name user password =
  case filter (not . null) [check "DB_HOST" host, check "DB_PORT" port, check "DB_NAME" name, check "DB_USER" user] of
    (err : _) -> Left err
    [] -> Right $ "host=" ++ host ++ " port=" ++ port ++ " dbname=" ++ name ++ " user=" ++ user ++ " password=" ++ password
  where
    check label value
      | null value = label ++ " must not be empty"
      | any (\c -> isSpace c || c == '\'' || c == '\\') value = label ++ " contains an invalid character"
      | otherwise = ""

-- | Fail-fast pool construction from the documented environment variables.
createPoolFromEnv :: IO ConnectionPool
createPoolFromEnv = do
  host <- requireEnv "DB_HOST"
  port <- fromMaybe "5432" <$> lookupEnv "DB_PORT"
  name <- fromMaybe "surypus" <$> lookupEnv "DB_NAME"
  user <- fromMaybe "postgres" <$> lookupEnv "DB_USER"
  password <- fromMaybe "" <$> lookupEnv "DB_PASSWORD"
  case buildConnectionString host port name user password of
    Left err -> ioError (userError err)
    Right connStr -> createPoolWith connStr 10
  where
    requireEnv key = do
      value <- lookupEnv key
      maybe (ioError (userError (key ++ " is required (fail-fast)"))) pure value

closePool :: ConnectionPool -> IO ()
closePool = destroyAllResources

runDb :: ConnectionPool -> SqlPersistT IO a -> IO a
runDb pool action = do
  mCtx <- currentTenantContext
  case mCtx of
    Just (tenantId, userId) ->
      runSqlPool (do
        _ <- rawSql "SELECT set_config('app.tenant_id', ?, TRUE)" [PersistText (T.pack $ show tenantId)] :: SqlPersistT IO [Single Text]
        _ <- rawSql "SELECT set_config('app.user_id', ?, TRUE)" [PersistText (T.pack $ show userId)] :: SqlPersistT IO [Single Text]
        result <- action
        _ <- rawSql "SELECT set_config('app.tenant_id', '', TRUE)" [] :: SqlPersistT IO [Single Text]
        _ <- rawSql "SELECT set_config('app.user_id', '', TRUE)" [] :: SqlPersistT IO [Single Text]
        pure result
        ) pool
    Nothing ->
      runSqlPool action pool

-- | Run a database action scoped to a specific tenant.
-- Sets the tenant context before the action and clears it after.
runDbWithTenant :: Int64 -> Int64 -> ConnectionPool -> SqlPersistT IO a -> IO a
runDbWithTenant tenantId userId pool action =
  runSqlPool (do
    _ <- rawSql "SELECT set_config('app.tenant_id', ?, TRUE)" [PersistText (T.pack $ show tenantId)] :: SqlPersistT IO [Single Text]
    _ <- rawSql "SELECT set_config('app.user_id', ?, TRUE)" [PersistText (T.pack $ show userId)] :: SqlPersistT IO [Single Text]
    result <- action
    _ <- rawSql "SELECT set_config('app.tenant_id', '', TRUE)" [] :: SqlPersistT IO [Single Text]
    _ <- rawSql "SELECT set_config('app.user_id', '', TRUE)" [] :: SqlPersistT IO [Single Text]
    pure result
    ) pool
