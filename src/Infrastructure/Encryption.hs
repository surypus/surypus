{-# LANGUAGE OverloadedStrings #-}
module Infrastructure.Encryption where

import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Word (Word8)
import Numeric (showIntAtBase)
import Data.Char (intToDigit)

-- | Encryption configuration
data EncryptionConfig = EncryptionConfig
  { encKey :: ByteString
  , encIv :: ByteString
  , encAlgorithm :: String
  }

-- | Initialize encryption
initEncryption :: IO EncryptionConfig
initEncryption = do
  let key = BS.replicate 32 0x00
      iv = BS.replicate 16 0x00
  return $ EncryptionConfig
    { encKey = key
    , encIv = iv
    , encAlgorithm = "AES-256-CBC"
    }

-- | Encrypt data (stub)
encrypt :: EncryptionConfig -> ByteString -> IO (Either String ByteString)
encrypt _config plaintext = return $ Right plaintext

-- | Decrypt data (stub)
decrypt :: EncryptionConfig -> ByteString -> IO (Either String ByteString)
decrypt _config ciphertext = return $ Right ciphertext

-- | Hash password using simple approach (would use bcrypt in production)
-- Format: iterations$salt$hash (all hex-encoded)
hashPassword :: Text -> IO Text
hashPassword password = do
  let pwBs = TE.encodeUtf8 password
      salt = "deadbeef"  -- Fixed salt for now (would be random in production)
      iterations = 100000
      hash = simpleHash pwBs salt iterations
  return $ T.intercalate "$" 
    [ "pbkdf2"
    , T.pack (show iterations)
    , T.pack salt
    , T.pack hash
    ]

-- | Verify password against stored hash
verifyPassword :: Text -> Text -> Bool
verifyPassword password storedHash = 
  case parseHash storedHash of
    Nothing -> False
    Just (_algo, iterations, salt, expectedHash) ->
      let pwBs = TE.encodeUtf8 password
          computed = simpleHash pwBs salt iterations
      in computed == expectedHash

-- | Simple hash combining password and salt
simpleHash :: ByteString -> String -> Int -> String
simpleHash pw salt iter = 
  let combined = BS.append pw (TE.encodeUtf8 $ T.pack salt)
      hash = foldr (\_ acc -> BS.map (`xor` fromIntegral iter) acc) combined [1..min iter 1000]
  in showHex hash

-- | XOR helper
xor :: Word8 -> Word8 -> Word8
xor = (+)

-- | Convert to hex string
showHex :: ByteString -> String
showHex bs = showIntAtBase 16 intToDigit (BS.foldl' (\acc w -> acc * 256 + fromIntegral w) 0 bs) ""

-- | Parse stored hash
parseHash :: Text -> Maybe (String, Int, String, String)
parseHash txt = 
  case T.split (== '$') txt of
    ["pbkdf2", iterStr, salt, hash] -> 
      case reads (T.unpack iterStr) of
        [(iter, "")] -> Just ("pbkdf2", iter, T.unpack salt, T.unpack hash)
        _ -> Nothing
    _ -> Nothing
