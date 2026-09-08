{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

{- | SMTP email infrastructure module.
Provides configurable email sending backed by smtp-mail and mime-mail.
SMTP credentials are loaded from environment variables (never hardcoded).
-}
module Infrastructure.Email (
    EmailConfig (..),
    loadEmailConfig,
    sendEmail,
) where

import Control.Exception (SomeException, try)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

import Network.Mail.Mime (Address (..), simpleMail')
import Network.Mail.SMTP (sendMailWithLogin')

-- | SMTP server configuration loaded from environment variables.
data EmailConfig = EmailConfig
    { ecSmtpHost :: !Text
    -- ^ SMTP server hostname
    , ecSmtpPort :: !Int
    -- ^ SMTP server port (default 587)
    , ecSmtpUser :: !Text
    -- ^ SMTP authentication username
    , ecSmtpPass :: !Text
    -- ^ SMTP authentication password
    , ecFromAddr :: !Text
    -- ^ Sender email address
    , ecFromName :: !Text
    -- ^ Sender display name
    }
    deriving (Show, Eq)

{- | Load SMTP configuration from environment variables.
Returns 'Left' with error message if required variables are missing.
Optional variables fall back to sensible defaults.
-}
loadEmailConfig :: IO (Either Text EmailConfig)
loadEmailConfig = do
    mHost <- lookupEnv "SURYPUS_SMTP_HOST"
    mPort <- lookupEnv "SURYPUS_SMTP_PORT"
    mUser <- lookupEnv "SURYPUS_SMTP_USERNAME"
    mPass <- lookupEnv "SURYPUS_SMTP_PASSWORD"
    mFrom <- lookupEnv "SURYPUS_EMAIL_FROM"
    mFromName <- lookupEnv "SURYPUS_EMAIL_FROM_NAME"
    case mHost of
        Nothing -> pure $ Left "SURYPUS_SMTP_HOST environment variable not set"
        Just host -> do
            let port = case mPort of
                    Just p -> readMaybe p
                    Nothing -> Just 587
                user = T.pack $ fromMaybe "" mUser
                pass = T.pack $ fromMaybe "" mPass
                fromAddr = T.pack $ fromMaybe "noreply@surypus.local" mFrom
                fromName = T.pack $ fromMaybe "Surypus ERP" mFromName
            pure $ case port of
                Just p -> Right $ EmailConfig (T.pack host) p user pass fromAddr fromName
                Nothing -> Left "SURYPUS_SMTP_PORT must be a valid integer"

{- | Send an email via the configured SMTP server.
Uses STARTTLS on port 587 by default (ecSmtpPort field).
Returns 'Right ()' on success, 'Left errorMessage' on failure.
-}
sendEmail :: EmailConfig -> Text -> Text -> Text -> IO (Either Text ())
sendEmail cfg recipient subject body = do
    let from = Address (Just $ ecFromName cfg) (ecFromAddr cfg)
        to = Address Nothing recipient
        mail = simpleMail' to from subject (LT.fromStrict body)
    result <-
        try $
            sendMailWithLogin'
                (T.unpack $ ecSmtpHost cfg)
                (fromIntegral $ ecSmtpPort cfg)
                (T.unpack $ ecSmtpUser cfg)
                (T.unpack $ ecSmtpPass cfg)
                mail
    case result of
        Right _ -> pure $ Right ()
        Left (e :: SomeException) -> pure $ Left (T.pack $ show e)
