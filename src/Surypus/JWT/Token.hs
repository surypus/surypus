{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -Wno-deprecations #-}

{- | JWT token generation and verification using jose-0.10
Provides cryptographically signed JWTs using HS256 (HMAC-SHA256)
-}
module Surypus.JWT.Token (
    generateToken,
    verifyToken,
    UserClaims (..),
) where

import Control.Exception (throwIO)
import Control.Lens ((&), (?~), (^.))
import Crypto.JOSE.Compact (encodeCompact)
import Crypto.JOSE.JWA.JWS (Alg (..))
import Crypto.JOSE.JWK (fromOctets)
import Crypto.JOSE.JWS (newJWSHeader)
import Crypto.JWT (
    JWTError,
    NumericDate (..),
    SignedJWT,
    addClaim,
    claimExp,
    claimIat,
    decodeCompact,
    defaultJWTValidationSettings,
    emptyClaimsSet,
    runJOSE,
    signClaims,
    unregisteredClaims,
    verifyClaims,
 )
import Data.Aeson (Value (..), toJSON)
import Data.ByteString.Lazy qualified as LBS
import Data.Int (Int64)
import Data.Map qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.Time.Clock (addUTCTime, getCurrentTime)
import DAL.Types (User (..))
import DAL.Pool (ConnectionPool)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

-- | User claims extracted from a valid JWT
data UserClaims = UserClaims
    { ucUserId :: !Int64
    , ucUsername :: !Text
    , ucRoles :: ![Text]
    , ucTenantId :: !(Maybe Int64)
    }
    deriving (Show, Eq)

{- | Get the JWT signing key from SURYPUS_JWT_SECRET env var.
Fails with a clear error if the environment variable is not set.
-}
getSigningKey :: IO LBS.ByteString
getSigningKey = do
    mbSecret <- lookupEnv "SURYPUS_JWT_SECRET"
    case mbSecret of
        Nothing -> error "FATAL: SURYPUS_JWT_SECRET environment variable is not set. Set it to a secure random string before starting the server."
        Just s -> pure $ LBS.fromStrict $ TE.encodeUtf8 $ T.pack s

{- | Generate a signed JWT token for the given user
The Pool parameter is reserved for future use (e.g., token revocation DB checks)
-}
generateToken :: ConnectionPool -> User -> IO Text
generateToken _pool user = do
    now <- getCurrentTime
    let uid = T.pack $ show $ userId user
        realTenantId = userTenantId user
    secret <- getSigningKey
    result <- runJOSE @JWTError $ do
        let jwk = fromOctets secret
            header = newJWSHeader ((), HS256)
            claims =
                addClaim "sub" (toJSON uid) $
                    addClaim "name" (toJSON $ userName user) $
                        addClaim "role" (toJSON ([] :: [Text])) $
                            addClaim "tenant_id" (Number (fromIntegral realTenantId)) $
                                addClaim "aud" (toJSON ("surypus-api" :: Text)) $
                                    emptyClaimsSet
                                        & claimIat ?~ NumericDate now
                                        & claimExp ?~ NumericDate (addUTCTime 3600 now)
        signClaims jwk header claims
    case result of
        Left jwtErr -> throwIO $ userError $ "JWT signing failed: " ++ show jwtErr
        Right signedJWT ->
            pure $ TE.decodeUtf8 $ LBS.toStrict $ encodeCompact signedJWT

-- | Verify and decode a JWT token, returning user claims on success
verifyToken :: Text -> IO (Either String UserClaims)
verifyToken tokenStr = do
    let tokenBs = LBS.fromStrict $ TE.encodeUtf8 tokenStr
    secret <- getSigningKey
    result <- runJOSE @JWTError $ do
        let jwk = fromOctets secret
            -- IN PRODUCTION: replace (const True) with actual audience/issuer validation:
            -- let expectedAudience = "surypus-api"
            --     config = defaultJWTValidationSettings (== expectedAudience)
            config = defaultJWTValidationSettings (== "surypus-api")
        jwt <- decodeCompact tokenBs
        verifyClaims config jwk (jwt :: SignedJWT)
    case result of
        Left jwtErr -> pure $ Left $ show jwtErr
        Right claimsSet -> do
            let custClaims = claimsSet ^. unregisteredClaims
                lookupClaim :: Text -> Maybe Value
                lookupClaim key = Map.lookup key custClaims
                mbUid =
                    lookupClaim "sub" >>= \case
                        String s -> Just s
                        _ -> Nothing
                mbName =
                    lookupClaim "name" >>= \case
                        String s -> Just s
                        _ -> Nothing
                mbRole =
                    lookupClaim "role" >>= \case
                        String s -> Just $ T.splitOn "," s
                        _ -> Nothing
                mbTenantId =
                    lookupClaim "tenant_id" >>= \case
                        Number n -> Just (round n)
                        String s -> case readMaybe (T.unpack s) of
                            Just tid -> Just tid
                            Nothing -> Nothing
                        _ -> Nothing
            case mbUid of
                Just uid -> case readMaybe (T.unpack uid) of
                    Just uidInt ->
                        pure $
                            Right $
                                UserClaims
                                    { ucUserId = uidInt
                                    , ucUsername = fromMaybe "" mbName
                                    , ucRoles = fromMaybe [] mbRole
                                    , ucTenantId = mbTenantId
                                    }
                    Nothing -> pure $ Left "Invalid token: sub claim is not a valid integer"
                _ -> pure $ Left "Invalid token: missing or invalid sub claim"
