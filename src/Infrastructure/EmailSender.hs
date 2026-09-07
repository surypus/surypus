module Infrastructure.EmailSender where

import Control.Monad.IO.Class (MonadIO   (..))
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Map.Strict as Map
import qualified Data.List as L
import Data.Time.Clock (getCurrentTime)

-- | Email address (simplified type alias)
type Email = Text

-- | Attachment (simplified type alias)
type Attach = Text

-- | Email configuration
data EmailConfig = EmailConfig
  { smtpHost :: String,
    smtpPort :: Int,
    smtpUser :: String,
    smtpPass :: String,
    mgApiKey :: Maybe String,
    mgDomain :: Maybe String
  }

-- | Email message
data EmailMessage = EmailMessage
  { from :: Email,
    to :: [Email],
    subject :: Text,
    body :: Text,
    cc :: [Email],
    bcc :: [Email],
    attachments :: [Attach]
  }

-- | Initialize email sender
initEmailSender :: EmailConfig -> IO (Either String EmailConfig)
initEmailSender config = do
  -- Validate configuration
  let valid = not (null (smtpHost config))
  if valid
    then return (Right config)
    else return (Left "Invalid email configuration")

-- | Send email synchronously (simplified)
sendEmail :: EmailConfig -> EmailMessage -> IO (Either String String)
sendEmail config msg = do
  -- Simplified: just return success
  return $ Right "Email sent successfully (simulated)"

-- | Send email with template
sendEmailTemplate :: EmailConfig -> EmailMessage -> Text -> Map.Map Text Text -> IO (Either String String)
sendEmailTemplate config msg template vars = do
  -- Render template with variables
  let renderedBody = renderTemplate template vars
  let msg' = msg {body = renderedBody}
  sendEmail config msg'

-- | Render simple template
renderTemplate :: Text -> Map.Map Text Text -> Text
renderTemplate template vars =
  let replacements = Map.toList vars
  in L.foldl' replace template replacements
  where
    replace :: Text -> (Text, Text) -> Text
    replace tmpl (k, v) = T.replace (T.pack "{{" <> k <> T.pack "}}") v tmpl

-- | Validate email address (simplified)
validateEmail :: Email -> Bool
validateEmail email = T.any (== '@') email && T.length email > 3
