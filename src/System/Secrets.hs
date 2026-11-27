{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Secret storage with authenticated encryption at rest.
--
-- The previous implementation kept plaintext in an IORef while presenting an
-- "encrypted store" API. Values are now sealed with AES-256-GCM-SIV before
-- entering the store; ciphertext never contains the plaintext, and tampering
-- is detected on retrieval.
module System.Secrets where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Crypto.Cipher.AES (AES256)
import qualified Crypto.Cipher.AESGCMSIV as GCM
import Crypto.Cipher.Types (AuthTag (..), cipherInit)
import Crypto.Error (throwCryptoError)
import Crypto.Random (getRandomBytes)
import qualified Data.ByteArray as BA
import qualified Data.ByteString as BS
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import Data.Time.Clock (NominalDiffTime, UTCTime, getCurrentTime)
import System.Environment (lookupEnv)

-- | Secret categories
data SecretCategory
  = DatabaseCredentials
  | APIKeys
  | EncryptionKeys
  | ServiceTokens
  | AdminCredentials
  deriving (Show, Eq, Ord)

-- | Secret metadata
data SecretMetadata = SecretMetadata
  { secretCategory :: SecretCategory,
    secretRotationPeriod :: NominalDiffTime,
    secretCreatedAt :: UTCTime,
    secretLastRotated :: UTCTime,
    secretVersion :: Int,
    secretTags :: [Text]
  }

-- | Nonce (12) + authentication tag (16) + ciphertext.
nonceLength :: Int
nonceLength = 12

tagLength :: Int
tagLength = 16

-- | Encrypted secret store. The map holds sealed values, never plaintext.
data SecretStore = SecretStore
  { secretMap :: TVar (Map.Map Text (BS.ByteString, SecretMetadata)),
    secretCipher :: AES256,
    rotationQueue :: TVar [Text],
    auditLog :: TVar [(UTCTime, Text, Text)]
  }

-- | Derive the store key from SURYPUS_SECRETS_KEY, or generate an ephemeral
-- one when the variable is absent. An ephemeral key means the store cannot be
-- restored across process restarts; the store itself is in-memory.
loadCipher :: IO AES256
loadCipher = do
  mbKey <- lookupEnv "SURYPUS_SECRETS_KEY"
  keyBytes <- case mbKey of
    Just value ->
      let raw = TE.encodeUtf8 (Text.pack value)
       in pure $ BS.take 32 (raw <> BS.replicate 32 0)
    Nothing -> getRandomBytes 32
  pure $ throwCryptoError (cipherInit keyBytes)

-- | Initialize secrets manager.
initSecretStore :: IO SecretStore
initSecretStore = do
  cipher <- loadCipher
  storeVar <- newTVarIO Map.empty
  queueVar <- newTVarIO []
  auditVar <- newTVarIO []
  pure $ SecretStore storeVar cipher queueVar auditVar

seal :: AES256 -> BS.ByteString -> IO BS.ByteString
seal cipher plaintext = do
  valueNonce <- GCM.generateNonce
  let (AuthTag tag, ciphertext) = encryptWith cipher valueNonce plaintext
  pure $ BS.concat [BA.convert valueNonce, BA.convert tag, ciphertext]
  where
    encryptWith c n p = GCM.encrypt c n (BS.empty :: BS.ByteString) p

unseal :: AES256 -> BS.ByteString -> Maybe BS.ByteString
unseal cipher blob
  | BS.length blob < nonceLength + tagLength = Nothing
  | otherwise =
      let (nonceBytes, rest) = BS.splitAt nonceLength blob
          (tagBytes, ciphertext) = BS.splitAt tagLength rest
          parsedNonce = throwCryptoError (GCM.nonce nonceBytes)
       in GCM.decrypt cipher parsedNonce (BS.empty :: BS.ByteString) ciphertext (AuthTag (BA.convert tagBytes :: BA.Bytes))

-- | Store a secret, encrypting the value before it reaches the map.
storeSecret :: SecretStore -> Text -> BS.ByteString -> SecretMetadata -> IO ()
storeSecret store key value metadata = do
  sealed <- seal (secretCipher store) value
  atomically $ do
    current <- readTVar (secretMap store)
    writeTVar (secretMap store) (Map.insert key (sealed, metadata) current)
  logAudit (auditLog store) ("STORE: " <> key) "secret_stored"

-- | Retrieve and authenticate a secret. Tampered values are not returned.
retrieveSecret :: SecretStore -> Text -> IO (Maybe BS.ByteString)
retrieveSecret store key = do
  entry <- atomically $ Map.lookup key <$> readTVar (secretMap store)
  case entry of
    Nothing -> do
      logAudit (auditLog store) ("RETRIEVE: " <> key) "not_found"
      pure Nothing
    Just (sealed, _) -> case unseal (secretCipher store) sealed of
      Just value -> do
        logAudit (auditLog store) ("RETRIEVE: " <> key) "success"
        pure $ Just value
      Nothing -> do
        logAudit (auditLog store) ("RETRIEVE: " <> key) "decryption_failed"
        pure Nothing

-- | Rotate a secret: the new value is sealed with the same key.
rotateSecret :: SecretStore -> Text -> BS.ByteString -> SecretMetadata -> IO ()
rotateSecret store key newValue newMetadata = do
  now <- getCurrentTime
  sealed <- seal (secretCipher store) newValue
  atomically $ do
    current <- readTVar (secretMap store)
    let metadata = newMetadata {secretVersion = secretVersion newMetadata + 1, secretLastRotated = now}
    writeTVar (secretMap store) (Map.insert key (sealed, metadata) current)
  logAudit (auditLog store) ("ROTATE: " <> key) "secret_rotated"

-- | Queue for rotation
queueRotation :: SecretStore -> Text -> IO ()
queueRotation store key = atomically $ do
  queue <- readTVar (rotationQueue store)
  writeTVar (rotationQueue store) (key : queue)

-- | Process rotation queue. No rotation policy is implemented yet; this
-- remains a no-op and is not advertised as functional.
processRotationQueue :: SecretStore -> IO ()
processRotationQueue _store = pure ()

-- | Audit helper. Key names are recorded; secret values never are.
logAudit :: TVar [(UTCTime, Text, Text)] -> Text -> Text -> IO ()
logAudit logVar action details = do
  now <- getCurrentTime
  atomically $ do
    audit <- readTVar logVar
    writeTVar logVar ((now, action, details) : audit)

-- | Generate a cryptographically secure random secret.
generateSecret :: Int -> IO BS.ByteString
generateSecret len = getRandomBytes len

-- | Validate secret metadata
validateSecretMetadata :: SecretMetadata -> Bool
validateSecretMetadata meta =
  secretVersion meta >= 0
    && not (Text.null (Text.pack (show (secretCategory meta))))
    && secretRotationPeriod meta > 0
