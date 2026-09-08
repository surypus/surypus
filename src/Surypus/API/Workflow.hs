{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.Workflow (
    Workflow (..),
    WorkflowInstance (..),
    WorkflowStatus (..),
    WorkflowInput (..),
    listWorkflows,
    createWorkflow,
    startWorkflow,
    getWorkflowInstance,
    listWorkflowInstances,
    completeWorkflowStep,
    completeWorkflow,
) where

import Control.Monad.IO.Class (liftIO)
import DAL.Types (QueryResult (..), Workflow (..), WorkflowInput (..), WorkflowInstance (..), WorkflowStatus (..))
import Data.Aeson (decode, encode)
import qualified Data.ByteString.Lazy as BL
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime)
import Database.Persist.Sql (ConnectionPool, PersistValue (..), rawExecute, rawSql, runSqlPool, Single (..))

-- | RawSql doesn't support WorkflowStatus directly, decode manually
parseInstance :: (Single Int64, Single Text, Single Int, Single (Maybe Text), Single (Maybe Text), Single (Maybe UTCTime), Single (Maybe UTCTime)) -> WorkflowInstance
parseInstance (Single i, Single wn, Single st, Single cs, Single ctx, Single sa, Single ca) =
    WorkflowInstance i 0 status cs input sa ca
  where
    status = case st of
        0 -> WorkflowPending
        1 -> WorkflowRunning
        2 -> WorkflowCompleted
        _ -> WorkflowFailed
    input = ctx >>= decode . BL.fromStrict . encodeUtf8

parseWorkflow :: (Single Int64, Single Text, Single (Maybe Text), Single Text, Single Bool, Single Text) -> Workflow
parseWorkflow (Single i, Single c, Single n, Single d, Single a, Single def) =
    Workflow i c n d a def

listWorkflows :: ConnectionPool -> IO (QueryResult [Workflow])
listWorkflows pool = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT id, code, name, description, is_active, definition::TEXT FROM workflows ORDER BY created_at DESC" []) pool
    return $ QuerySuccess (map parseWorkflow result)

createWorkflow :: ConnectionPool -> WorkflowInput -> IO (QueryResult Workflow)
createWorkflow pool input = do
    let (code, name, desc, def) = case wiInputData input of
            Just txt -> (txt, Nothing, Nothing, "{}")
            Nothing -> ("default", Nothing, Nothing, "{}")
    let params = [ PersistText code, maybe PersistNull PersistText name, maybe PersistNull PersistText desc, PersistText def ]
    result <- liftIO $ runSqlPool
        (rawSql "INSERT INTO workflows (code, name, description, definition) VALUES (?, ?, ?, ?::JSONB) RETURNING id, code, name, description, is_active, definition::TEXT" params) pool
    case result of
        (row:_) -> return $ QuerySuccess (parseWorkflow row)
        _ -> return $ QueryError "Failed to create workflow"

startWorkflow :: ConnectionPool -> Text -> Text -> IO (QueryResult WorkflowInstance)
startWorkflow pool workflowName initialContext = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT workflow_start(?, ?::JSONB)" [PersistText workflowName, PersistText initialContext]) pool
    case result of
        [(Single (instId :: Text))] -> do
            let instanceId = "00000000-0000-0000-0000-000000000000"
            getWorkflowInstance pool instId
        _ -> return $ QueryError "Failed to start workflow"

getWorkflowInstance :: ConnectionPool -> Text -> IO (QueryResult WorkflowInstance)
getWorkflowInstance pool iid = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT id, workflow_name::TEXT, status, current_step::TEXT, context::TEXT, started_at, completed_at FROM workflow_instances WHERE id = ?" [PersistText iid]) pool
    case result of
        (row:_) -> return $ QuerySuccess (parseInstance row)
        _ -> return $ QueryError "Not Found"

listWorkflowInstances :: ConnectionPool -> IO (QueryResult [WorkflowInstance])
listWorkflowInstances pool = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT id, workflow_name::TEXT, status, current_step::TEXT, context::TEXT, started_at, completed_at FROM workflow_instances ORDER BY started_at DESC" []) pool
    return $ QuerySuccess (map parseInstance result)

completeWorkflowStep :: ConnectionPool -> Text -> Int -> Text -> IO (QueryResult ())
completeWorkflowStep pool iid nextStep contextUpdate = do
    liftIO $ runSqlPool
        (rawExecute "SELECT workflow_step_complete(?, ?, ?::JSONB)" [PersistText iid, PersistInt64 (fromIntegral nextStep), PersistText contextUpdate]) pool
    return $ QuerySuccess ()

completeWorkflow :: ConnectionPool -> Text -> IO (QueryResult ())
completeWorkflow pool iid = do
    liftIO $ runSqlPool
        (rawExecute "SELECT workflow_complete(?)" [PersistText iid]) pool
    return $ QuerySuccess ()
