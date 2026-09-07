{-# LANGUAGE OverloadedStrings #-}
-- | JWT Token verification (Surypus flavor)
module Surypus.JWT.Token
  ( UserClaims(..)
  , verifyToken
  , createToken
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8, decodeUtf8)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Base64.URL as B64U
import Data.Aeson (FromJSON, ToJSON, eitherDecode, encode)
import GHC.Generics (Generic)
import Data.Time.Clock (UTCTime, getCurrentTime)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)

-- | User claims embedded in JWT
data UserClaims = UserClaims
  { claimsUserId :: !Int
  , claimsUsername :: !Text
  , claimsEmail :: !(Maybe Text)
  , claimsRoles :: ![Text]
  , claimsExpiry :: !Int64
  , claimsIssuedAt :: !Int64
  } deriving (Show, Eq, Generic)

instance FromJSON UserClaims
instance ToJSON UserClaims

-- | Simple HMAC-SHA256 JWT implementation
newtype SecretKey = SecretKey ByteString

-- | Get default secret key (in production, this should come from environment/config)
defaultSecretKey :: SecretKey
defaultSecretKey = SecretKey "surypus-default-secret-key-change-in-production"

-- | Create a JWT token for the given claims
createToken :: SecretKey -> UserClaims -> IO Text
createToken (SecretKey secret) claims = do
  let header = BL.toStrict $ encode $ object
        [ "typ" .= ("JWT" :: Text)
        , "alg" .= ("HS256" :: Text)
        ]
      payload = BL.toStrict $ encode claims
      headerB64 = B64U.encode header
      payloadB64 = B64U.encode payload
      signingInput = headerB64 <> "." <> payloadB64
      signature = hmacSign secret signingInput
      signatureB64 = B64U.encode signature
  return $ signingInput <> "." <> signatureB64

-- | Verify a JWT token and extract claims
verifyToken :: SecretKey -> Text -> IO (Either Text UserClaims)
verifyToken secret token = do
  let parts = T.splitOn "." token
  case parts of
    [headerB64, payloadB64, signatureB64] -> do
      let signingInput = headerB64 <> "." <> payloadB64
          expectedSig = hmacSign (case secret of SecretKey k -> k) (encodeUtf8 signingInput)
          expectedB64 = B64U.encode expectedSig
      if signatureB64 /= expectedB64
        then return $ Left "Invalid signature"
        else case B64U.decode (encodeUtf8 payloadB64) of
          Left err -> return $ Left $ "Decode error: " <> T.pack err
          Right payload -> case eitherDecode (BL.fromStrict payload) of
            Left err -> return $ Left $ "JSON error: " <> T.pack err
            Right claims -> do
              now <- getCurrentTime
              let expiry = posixSecondsToUTCTime (fromIntegral (claimsExpiry claims) / 1000)
              if now > expiry
                then return $ Left "Token expired"
                else return $ Right claims
    _ -> return $ Left "Invalid token format"

-- | HMAC-SHA256 signing
hmacSign :: ByteString -> ByteString -> ByteString
hmacSign key msg = convert (hmac key msg :: HMAC SHA256)

-- | Helper for JSON object construction
object :: [Text] -> Text
object pairs = T.intercalate "," pairs

(.=) :: Text -> Text -> Text
k .= v = k <> ":" <> v
