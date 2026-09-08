{-# LANGUAGE OverloadedStrings #-}
module Surypus.API.RateLimiter
  ( RateLimiterConfig(..)
  , RateLimiterState(..)
  , initRateLimiter
  , rateLimiterMiddleware
  , defaultRateLimiterConfig
  ) where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe)
import Data.Sequence (Seq)
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time.Clock (NominalDiffTime, UTCTime, diffUTCTime, getCurrentTime)
import Network.HTTP.Types (status429)
import Network.Socket (SockAddr(..))
import Network.Wai (Application, Request, requestHeaders, responseLBS, mapResponseHeaders)
import qualified Network.Wai as W
import qualified Surypus.JWT.Token as JWT
import qualified Data.ByteString.Char8 as BS

data RateLimiterConfig = RateLimiterConfig
  { rlcDefaultIpLimit :: !Int
  , rlcDefaultTenantLimit :: !Int
  , rlcWindowSec :: !Int
  , rlcTenantOverrides :: !(Map Int64 Int)
  }

data RateLimiterState = RateLimiterState
  { rlsIpWindows :: !(TVar (Map Text (Seq UTCTime)))
  , rlsTenantWindows :: !(TVar (Map Int64 (Seq UTCTime)))
  }

defaultRateLimiterConfig :: RateLimiterConfig
defaultRateLimiterConfig = RateLimiterConfig
  { rlcDefaultIpLimit = 100
  , rlcDefaultTenantLimit = 500
  , rlcWindowSec = 60
  , rlcTenantOverrides = M.empty
  }

initRateLimiter :: RateLimiterConfig -> IO RateLimiterState
initRateLimiter _cfg = do
  ipVar <- newTVarIO M.empty
  tenantVar <- newTVarIO M.empty
  return $ RateLimiterState ipVar tenantVar

rateLimiterMiddleware :: RateLimiterConfig -> RateLimiterState -> Application -> Application
rateLimiterMiddleware cfg state app req respond = do
  let clientIp = extractClientIp req

  (ipLimitOk, ipRemaining, ipReset) <- checkSlidingWindowWithHeaders
    (rlsIpWindows state)
    clientIp
    (rlcDefaultIpLimit cfg)
    (rlcWindowSec cfg)
  if not ipLimitOk
    then respond $ rateLimitedResponse 0 (rlcWindowSec cfg)
    else do
      (tenantOk, tenantRemaining, tenantReset) <- case extractBearerToken req of
        Just token -> do
          result <- JWT.verifyToken token
          case result of
            Right claims -> case JWT.ucTenantId claims of
              Just tid -> do
                let limit = fromMaybe (rlcDefaultTenantLimit cfg)
                          (M.lookup tid (rlcTenantOverrides cfg))
                checkSlidingWindowWithHeaders (rlsTenantWindows state) tid limit (rlcWindowSec cfg)
              Nothing -> return (True, rlcDefaultTenantLimit cfg, rlcWindowSec cfg)
            Left _ -> return (True, rlcDefaultTenantLimit cfg, rlcWindowSec cfg)
        Nothing -> return (True, rlcDefaultTenantLimit cfg, rlcWindowSec cfg)
      let limit = min (rlcDefaultIpLimit cfg) (if tenantOk then tenantRemaining else rlcDefaultTenantLimit cfg)
          remaining = min (ipRemaining) (if tenantOk then tenantRemaining else ipRemaining)
          resetTime = max (ipReset) tenantReset
      if tenantOk
        then app req $ \res ->
          respond $ addRateLimitHeaders limit remaining resetTime res
        else respond $ rateLimitedResponse remaining tenantReset

rateLimitedResponse :: Int -> Int -> W.Response
rateLimitedResponse remaining resetSec =
  responseLBS status429
    [ ("Content-Type", "application/json")
    , ("RateLimit-Limit", BS.pack (show remaining))
    , ("RateLimit-Remaining", "0")
    , ("RateLimit-Reset", BS.pack (show resetSec))
    ]
    "{\"error\":\"Rate limit exceeded\"}"

addRateLimitHeaders :: Int -> Int -> Int -> W.Response -> W.Response
addRateLimitHeaders limit remaining resetSec res =
  let headers = W.responseHeaders res
      newHeaders = headers ++
        [ ("RateLimit-Limit", BS.pack (show limit))
        , ("RateLimit-Remaining", BS.pack (show remaining))
        , ("RateLimit-Reset", BS.pack (show resetSec))
        ]
  in W.mapResponseHeaders (const newHeaders) res

extractClientIp :: Request -> Text
extractClientIp req =
  case lookup "x-forwarded-for" (W.requestHeaders req) of
    Just ips -> T.takeWhile (/= ',') (TE.decodeUtf8 ips)
    Nothing -> case W.remoteHost req of
      SockAddrInet _ addr -> T.pack (show addr)
      SockAddrInet6 _ _ addr _ -> T.pack (show addr)
      _ -> "unknown"

extractBearerToken :: Request -> Maybe Text
extractBearerToken req = do
  hdr <- lookup "Authorization" (W.requestHeaders req)
  let hdrStr = TE.decodeUtf8 hdr
  T.stripPrefix "Bearer " hdrStr

checkSlidingWindow :: (Ord k) => TVar (Map k (Seq UTCTime)) -> k -> Int -> Int -> IO Bool
checkSlidingWindow var key limit windowSec = do
  (ok, _, _) <- checkSlidingWindowWithHeaders var key limit windowSec
  return ok

checkSlidingWindowWithHeaders :: (Ord k) => TVar (Map k (Seq UTCTime)) -> k -> Int -> Int -> IO (Bool, Int, Int)
checkSlidingWindowWithHeaders var key limit windowSec = do
  now <- getCurrentTime
  let windowSize = fromIntegral windowSec :: NominalDiffTime
  atomically $ do
    m <- readTVar var
    let reqs = fromMaybe Seq.empty (M.lookup key m)
        valid = Seq.dropWhileL (\t -> diffUTCTime now t > windowSize) reqs
        remaining = limit - Seq.length valid
        resetSec = windowSec
    if Seq.length valid < limit
      then do
        writeTVar var (M.insert key (valid Seq.|> now) m)
        return (True, remaining, resetSec)
      else return (False, 0, resetSec)
