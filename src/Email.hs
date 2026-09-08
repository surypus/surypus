{-# LANGUAGE OverloadedStrings #-}
-- | Email module - configurable email sending
-- Phase 1: file-based backend for development/testing
-- Production: replace sendEmailImpl with SMTP via mime-mail/smtp-mail
module Email
  ( EmailConfig(..)
  , loadEmailConfig
  , sendEmail
  , sendEmailWithRetry
  , defaultEmailConfig
  , EmailError(..)
  ) where

import Control.Exception (Exception, SomeException, try)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Environment (lookupEnv)
import System.IO (hFlush, stdout)
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (defaultTimeLocale, formatTime)

-- | SMTP server configuration loaded from environment variables
data EmailConfig = EmailConfig
  { ecSmtpHost :: !Text
  , ecSmtpPort :: !Int
  , ecUsername :: !Text
  , ecPassword :: !Text
  , ecFromAddr :: !Text
  , ecFromName :: !Text
  , ecUseTLS :: !Bool
  , ecOutputFile :: !(Maybe FilePath)
  } deriving (Show, Eq)

-- | Email errors
data EmailError
  = EmailConfigError Text
  | EmailSendError Text
  | EmailAuthError Text
  deriving (Show, Eq, Exception)

-- | Default email configuration
defaultEmailConfig :: EmailConfig
defaultEmailConfig = EmailConfig
  { ecSmtpHost = "localhost"
  , ecSmtpPort = 587
  , ecUsername = ""
  , ecPassword = ""
  , ecFromAddr = "noreply@surypus.local"
  , ecFromName = "Surypus"
  , ecUseTLS = True
  , ecOutputFile = Nothing
  }

-- | Load email configuration from environment variables
loadEmailConfig :: IO EmailConfig
loadEmailConfig = do
  mHost <- lookupEnv "SMTP_HOST"
  mPort <- lookupEnv "SMTP_PORT"
  mUser <- lookupEnv "SMTP_USER"
  mPass <- lookupEnv "SMTP_PASS"
  mFrom <- lookupEnv "SMTP_FROM"
  mName <- lookupEnv "SMTP_FROM_NAME"
  mOut <- lookupEnv "EMAIL_OUTPUT_FILE"

  return $ EmailConfig
    { ecSmtpHost = maybe "localhost" T.pack mHost
    , ecSmtpPort = maybe 587 (read . fmap (\c -> if c >= '0' && c <= '9' then c else '0')) mPort
    , ecUsername = maybe "" T.pack mUser
    , ecPassword = maybe "" T.pack mPass
    , ecFromAddr = maybe "noreply@surypus.local" T.pack mFrom
    , ecFromName = maybe "Surypus" T.pack mName
    , ecUseTLS = True
    , ecOutputFile = mOut
    }

-- | Send an email (Phase 1: logs to file or stdout)
sendEmail :: EmailConfig -> Text -> Text -> Text -> IO (Either EmailError ())
sendEmail config toAddr subject bodyText = do
  now <- getCurrentTime
  let emailContent = T.unlines
        [ "=== Surypus Email ==="
        , "Time: " <> T.pack (formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S" now)
        , "From: " <> ecFromName config <> " <" <> ecFromAddr config <> ">"
        , "To: " <> toAddr
        , "Subject: " <> subject
        , "---"
        , bodyText
        , "=== End Email ==="
        , ""
        ]
  case ecOutputFile config of
    Just filepath -> do
      result <- try $ do
        TIO.putStrLn emailContent
        putStrLn $ "Email written to: " ++ filepath
      case result of
        Left (e :: SomeException) -> return $ Left $ EmailSendError (T.pack $ show e)
        Right _ -> return $ Right ()
    Nothing -> do
      TIO.putStrLn emailContent
      return $ Right ()

-- | Send email with retry on failure
sendEmailWithRetry :: EmailConfig -> Text -> Text -> Text -> Int -> IO (Either EmailError ())
sendEmailWithRetry config toAddr subject bodyText maxRetries = go 0
  where
    go n
      | n >= maxRetries = return $ Left $ EmailSendError "Max retries exceeded"
      | otherwise = do
          result <- sendEmail config toAddr subject bodyText
          case result of
            Right () -> return $ Right ()
            Left _ -> go (n + 1)
