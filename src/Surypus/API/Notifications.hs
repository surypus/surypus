{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.Notifications (
    NotificationPref (..),
    Notification (..),
    NotificationInput (..),
    NotificationPrefInput (..),
    getPreferences,
    updatePreferences,
    listNotifications,
    createNotification,
    markNotificationRead,
    getNotificationPrefs,
    updateNotificationPrefs,
    sendEmailNotification,
    sendDigestNotification,
    sendTestNotification,
) where

import Control.Monad (join)
import Control.Monad.IO.Class (liftIO)
import DAL.Types (QueryResult (..))
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Sql (ConnectionPool, PersistValue (..), rawExecute, rawSql, runSqlPool, Single (..))
import GHC.Generics (Generic)

data NotificationPref = NotificationPref
    { npEmail :: !Bool
    , npPush :: !Bool
    , npDigest :: !Text
    }
    deriving (Show, Eq, Generic)
instance ToJSON NotificationPref
instance FromJSON NotificationPref

data Notification = Notification
    { notifId :: !Text
    , notifTitle :: !Text
    , notifBody :: !(Maybe Text)
    , notifStatus :: !Text
    }
    deriving (Show, Eq, Generic)
instance ToJSON Notification

data NotificationInput = NotificationInput
    { niUserId :: !Int64
    , niTitle :: !Text
    , niBody :: !Text
    , niType :: !Text
    }
    deriving (Show, Eq, Generic)
instance ToJSON NotificationInput
instance FromJSON NotificationInput

data NotificationPrefInput = NotificationPrefInput
    { npiEmail :: !Bool
    , npiPush :: !Bool
    , npiDigest :: !Text
    }
    deriving (Show, Eq, Generic)
instance ToJSON NotificationPrefInput
instance FromJSON NotificationPrefInput

parseNotification :: (Single Text, Single Text, Single (Maybe Text), Single Text) -> Notification
parseNotification (Single i, Single t, Single b, Single s) = Notification i t b s

parsePref :: (Single Bool, Single Bool, Single Text) -> NotificationPref
parsePref (Single e, Single p, Single d) = NotificationPref e p d

listNotifications :: ConnectionPool -> Int64 -> IO (QueryResult [Notification])
listNotifications pool recipientId = do
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT id, subject, body, \
            \  CASE status WHEN 0 THEN 'draft' WHEN 1 THEN 'pending' WHEN 2 THEN 'sent' \
            \    WHEN 3 THEN 'delivered' WHEN 4 THEN 'read' ELSE 'archived' END \
            \FROM notification WHERE recipient_id = ? ORDER BY created_at DESC LIMIT 100"
            [PersistInt64 recipientId]) pool
    return $ QuerySuccess (map parseNotification result)

createNotification :: ConnectionPool -> NotificationInput -> IO (QueryResult Notification)
createNotification pool input = do
    let sql = "INSERT INTO notification (ntype, priority, recipient_id, subject, body, status) \
              \VALUES (1, 3, ?, ?, ?, 1) \
              \RETURNING id, subject, body, 'pending'"
    let params = [ PersistInt64 (niUserId input), PersistText (niTitle input), PersistText (niBody input) ]
    result <- liftIO $ runSqlPool (rawSql sql params) pool
    case result of
        (row:_) -> return $ QuerySuccess (parseNotification row)
        _ -> return $ QueryError "Failed to create notification"

markNotificationRead :: ConnectionPool -> Text -> IO (QueryResult ())
markNotificationRead pool nId = do
    liftIO $ runSqlPool
        (rawExecute "UPDATE notification SET status = 4, read_at = NOW() WHERE id = ?" [PersistText nId]) pool
    return $ QuerySuccess ()

getNotificationPrefs :: ConnectionPool -> Int64 -> IO (QueryResult NotificationPref)
getNotificationPrefs pool userId = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT notify_email, notify_push, digest_frequency FROM notification_prefs WHERE usr_id = ?" [PersistInt64 userId]) pool
    case result of
        (row:_) -> return $ QuerySuccess (parsePref row)
        _ -> return $ QuerySuccess (NotificationPref True True "daily")

updateNotificationPrefs :: ConnectionPool -> Int64 -> NotificationPrefInput -> IO (QueryResult NotificationPref)
updateNotificationPrefs pool userId input = do
    let sql = "WITH updated AS ("
              <> "UPDATE notification_prefs SET notify_email = ?, notify_push = ?, digest_frequency = ? "
              <> "WHERE usr_id = ? "
              <> "RETURNING notify_email, notify_push, digest_frequency "
              <> ") "
              <> "INSERT INTO notification_prefs (usr_id, notify_email, notify_push, digest_frequency) "
              <> "SELECT ?, ?, ?, ? "
              <> "WHERE NOT EXISTS (SELECT 1 FROM updated) "
              <> "RETURNING notify_email, notify_push, digest_frequency"
    let params = [ PersistBool (npiEmail input), PersistBool (npiPush input), PersistText (npiDigest input), PersistInt64 userId
                 , PersistInt64 userId, PersistBool (npiEmail input), PersistBool (npiPush input), PersistText (npiDigest input)
                 ]
    result <- liftIO $ runSqlPool (rawSql sql params) pool
    case result of
        (row:_) -> return $ QuerySuccess (parsePref row)
        _ -> return $ QueryError "Failed to update notification prefs"

getPreferences :: ConnectionPool -> IO (QueryResult NotificationPref)
getPreferences _pool = return $ QuerySuccess $ NotificationPref True True "daily"

updatePreferences :: ConnectionPool -> NotificationPref -> IO (QueryResult NotificationPref)
updatePreferences _pool prefs = return $ QuerySuccess prefs

lookupUserEmail :: ConnectionPool -> Int64 -> IO (Maybe Text)
lookupUserEmail pool userId = do
    result <- liftIO $ runSqlPool
        (rawSql "SELECT email FROM users WHERE id = ?" [PersistInt64 userId]) pool
    return $ case result of
        [(Single (mbEmail :: Maybe Text))] -> mbEmail
        _ -> Nothing

sendEmailNotification :: ConnectionPool -> NotificationInput -> IO (QueryResult ())
sendEmailNotification pool input = do
    result <- createNotification pool input
    case result of
        QuerySuccess _ -> do
            mbEmail <- lookupUserEmail pool (niUserId input)
            let _email = fromMaybe "user@surypus.local" mbEmail
            -- Mock: email sending disabled in Phase 1 prototype
            return $ QuerySuccess ()
        QueryError err -> return $ QueryError err

sendDigestNotification :: ConnectionPool -> Int64 -> Text -> IO (QueryResult ())
sendDigestNotification pool userId frequency = do
    let input =
            NotificationInput
                userId
                ("Digest: " <> frequency)
                ("Your " <> frequency <> " digest notification")
                "digest"
    result <- createNotification pool input
    case result of
        QuerySuccess _ -> return $ QuerySuccess ()
        QueryError err -> return $ QueryError err

sendTestNotification :: ConnectionPool -> IO (QueryResult ())
sendTestNotification pool = do
    let input = NotificationInput 1 "Test Notification" "This is a test notification" "test"
    result <- createNotification pool input
    case result of
        QuerySuccess _ -> return $ QuerySuccess ()
        QueryError err -> return $ QueryError err
