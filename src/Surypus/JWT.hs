{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -Wno-deprecations #-}
module Surypus.JWT
  ( JWTConfig   (..),
    TokenPair   (..),
    AuthError   (..),
    jwtConfigFromSecret,
    generateTokenPair,
    validateRefreshToken,
    validateAccessToken,
    accessToken,
    refreshToken,
    rtUserId,
    rtExpiresAt,
    decodeAndValidateToken,
    refreshAccessToken,
  ) where

import Crypto.JOSE.Compact (encodeCompact)
import Crypto.JOSE.JWA.JWS (Alg (HS256))
import Crypto.JOSE.JWK (fromOctets)
import Crypto.JOSE.JWS (newJWSHeader)
import Crypto.JWT
  ( JWTError,
    NumericDate (..),
    SignedJWT,
    addClaim,
    claimExp,
    claimIat,
    claimSub,
    decodeCompact,
    defaultJWTValidationSettings,
    emptyClaimsSet,
    runJOSE,
    signClaims,
    string,
    unregisteredClaims,
    verifyClaims,
  )
import Control.Lens ((&), (?~), (^.), (^?), review)
import DAL.Database (ConnectionPool)
import Data.Aeson (Value (..), toJSON)
import Data.ByteString.Lazy qualified as LBS
import Data.Int (Int64)
import Data.Map qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Data.Time.Clock (NominalDiffTime)
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUIDv4
import qualified Surypus.RefreshTokenRepo as RTRepo
import Text.Read (readMaybe)

data AuthError = AuthExpired | AuthInvalid | AuthMissing | AuthMalformed
  deriving (Show, Eq)

data JWTConfig = JWTConfig
  { jwtSecret :: Text,
    jwtExpiry :: NominalDiffTime,
    jwtRefreshExpiry :: NominalDiffTime
  }
  deriving (Show, Eq)

jwtConfigFromSecret :: Text -> JWTConfig
jwtConfigFromSecret secret =
  JWTConfig
    { jwtSecret = secret,
      jwtExpiry = 3600,
      jwtRefreshExpiry = 1209600
    }

data TokenPair = TokenPair
  { tpAccessToken :: Text,
    tpRefreshToken :: Text,
    tpExpiresAt :: UTCTime
  }
  deriving (Show, Eq)

accessToken :: TokenPair -> Text
accessToken = tpAccessToken

refreshToken :: TokenPair -> Text
refreshToken = tpRefreshToken

rtUserId :: TokenPair -> Int64
rtUserId = const 0

rtExpiresAt :: TokenPair -> UTCTime
rtExpiresAt = tpExpiresAt

getSigningKey :: Text -> LBS.ByteString
getSigningKey secret = LBS.fromStrict $ TE.encodeUtf8 secret

generateTokenPair :: ConnectionPool -> JWTConfig -> Int64 -> Text -> Text -> Maybe Int64 -> IO TokenPair
generateTokenPair pool cfg userId username role _mPersonId = do
  now <- getCurrentTime
  let expiresAt = addUTCTime (jwtExpiry cfg) now
      refreshExpiresAt = addUTCTime (jwtRefreshExpiry cfg) now
      jwk = fromOctets $ getSigningKey $ jwtSecret cfg
      header = newJWSHeader ((), HS256)
      uid = T.pack (show userId)
      claims =
                  addClaim "name" (toJSON username) $
            addClaim "role" (toJSON role) $
              addClaim "aud" (toJSON ("surypus-api" :: Text)) $
                emptyClaimsSet
                  & claimSub ?~ review string uid
                  & claimIat ?~ NumericDate now
                  & claimExp ?~ NumericDate expiresAt
  result <- runJOSE @JWTError $ signClaims jwk header claims
  case result of
    Left err -> ioError $ userError $ "JWT signing failed: " ++ show err
    Right signedJWT -> do
      let accessTok = TE.decodeUtf8 $ LBS.toStrict $ encodeCompact signedJWT
      refreshTokenUuid <- UUIDv4.nextRandom
      let refreshTok = UUID.toText refreshTokenUuid
          refreshExpiresStr = T.pack (show refreshExpiresAt)
      _ <- RTRepo.storeRefreshToken pool userId refreshTok refreshExpiresStr
      pure TokenPair
        { tpAccessToken = accessTok,
          tpRefreshToken = refreshTok,
          tpExpiresAt = expiresAt
        }

validateRefreshToken :: ConnectionPool -> JWTConfig -> Text -> IO (Either Text TokenPair)
validateRefreshToken pool cfg token = do
  result <- RTRepo.validateRefreshToken pool token
  case result of
    Left err -> pure $ Left err
    Right userId -> do
      now <- getCurrentTime
      let expiresAt = addUTCTime (jwtExpiry cfg) now
      pure $ Right TokenPair
        { tpAccessToken = "",
          tpRefreshToken = token,
          tpExpiresAt = expiresAt
        }

validateAccessToken :: Text -> Text -> IO (Either Text Int64)
validateAccessToken secret token = do
  let jwk = fromOctets $ getSigningKey secret
      tokenBs = LBS.fromStrict $ TE.encodeUtf8 token
  result <- runJOSE @JWTError $ do
    jwt <- decodeCompact tokenBs
    verifyClaims (defaultJWTValidationSettings (== "surypus-api")) jwk (jwt :: SignedJWT)
  case result of
    Left _ -> pure $ Left "Invalid or expired token"
    Right claimsSet -> do
      let custClaims = claimsSet ^. unregisteredClaims
          mbUid = (claimsSet ^. claimSub) >>= (^? string)
      case mbUid of
        Just uid -> case readMaybe (T.unpack uid) of
          Just uidInt -> pure $ Right uidInt
          Nothing -> pure $ Left "Invalid token: sub claim is not a valid integer"
        _ -> pure $ Left "Invalid token: missing sub claim"

decodeAndValidateToken :: Text -> Text -> IO (Either AuthError (Int64, Text, UTCTime))
decodeAndValidateToken secret token = do
  now <- getCurrentTime
  let jwk = fromOctets $ getSigningKey secret
      tokenBs = LBS.fromStrict $ TE.encodeUtf8 token
  result <- runJOSE @JWTError $ do
    jwt <- decodeCompact tokenBs
    verifyClaims (defaultJWTValidationSettings (== "surypus-api")) jwk (jwt :: SignedJWT)
  case result of
    Left _ -> pure $ Left AuthInvalid
    Right claimsSet -> do
      let custClaims = claimsSet ^. unregisteredClaims
          lookupClaim k =
            Map.lookup k custClaims >>= \case
              String s -> Just s
              _ -> Nothing
          mbUid = (claimsSet ^. claimSub) >>= (^? string)
          mbName = lookupClaim "name"
          mbExp = claimsSet ^. claimExp
      case mbUid of
        Just uid -> case readMaybe (T.unpack uid) of
          Just uidInt ->
            let expiresAt = case mbExp of
                  Just (NumericDate t) -> t
                  Nothing -> addUTCTime 3600 now
             in pure $ Right (uidInt, fromMaybe "" mbName, expiresAt)
          Nothing -> pure $ Left AuthInvalid
        _ -> pure $ Left AuthInvalid

--------------------------------------------------------------------------------
-- Refresh-token rotation + access-token reissue
--------------------------------------------------------------------------------

-- | Validate a refresh token, rotate it (revoke the old one, store a new UUID),
-- and issue a fresh access token. Proper rotation prevents refresh-token replay:
-- a stolen token becomes useless after the first refresh, because the old token
-- is deleted on rotation.
refreshAccessToken :: ConnectionPool -> JWTConfig -> Text -> IO (Either Text TokenPair)
refreshAccessToken pool cfg oldToken = do
  validated <- RTRepo.validateRefreshToken pool oldToken
  case validated of
    Left err -> pure $ Left err
    Right userId -> do
      newRefreshUuid <- UUIDv4.nextRandom
      let newRefreshTok = UUID.toText newRefreshUuid
      now <- getCurrentTime
      let refreshExpiresAt = addUTCTime (jwtRefreshExpiry cfg) now
          refreshExpiresStr = T.pack (show refreshExpiresAt)
          accessExpiresAt = addUTCTime (jwtExpiry cfg) now
      rotated <- RTRepo.rotateStoredRefreshToken pool oldToken newRefreshTok refreshExpiresStr
      case rotated of
        Left err -> pure $ Left err
        Right _ -> do
          let jwk = fromOctets $ getSigningKey $ jwtSecret cfg
              header = newJWSHeader ((), HS256)
              uid = T.pack (show userId)
              claims =
                                  addClaim "name" (toJSON ("" :: Text)) $
                    addClaim "role" (toJSON ("" :: Text)) $
                      addClaim "aud" (toJSON ("surypus-api" :: Text)) $
                        emptyClaimsSet
                          & claimSub ?~ review string uid
                          & claimIat ?~ NumericDate now
                          & claimExp ?~ NumericDate accessExpiresAt
          signed <- runJOSE @JWTError $ signClaims jwk header claims
          case signed of
            Left jwtErr -> pure $ Left $ T.pack $ "JWT signing failed: " ++ show jwtErr
            Right signedJWT ->
              pure $ Right TokenPair
                { tpAccessToken = TE.decodeUtf8 $ LBS.toStrict $ encodeCompact signedJWT
                , tpRefreshToken = newRefreshTok
                , tpExpiresAt = accessExpiresAt
                }
