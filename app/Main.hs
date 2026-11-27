{-# LANGUAGE OverloadedStrings #-}

-- | Surypus server entrypoint (Phase 1 bootstrap).
--
-- Fail-fast configuration: DB_HOST is mandatory; the process exits before
-- binding the port when it is missing. GET /api/v1/health performs a real TCP
-- probe of the configured database host and returns 503 when it is unreachable.
module Main (main) where

import Control.Exception (SomeException, bracket, try)
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.Maybe (fromMaybe)
import Network.HTTP.Types (hContentType, status200, status404, status503)
import Network.Socket
  ( AddrInfo (..),
    SocketType (Stream),
    close,
    connect,
    defaultHints,
    getAddrInfo,
    openSocket,
    addrAddress,
  )
import Network.Wai (Application, Request (pathInfo, requestMethod), responseLBS)
import Network.Wai.Handler.Warp (run)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.Timeout (timeout)

main :: IO ()
main = do
  host <- lookupEnv "DB_HOST" >>= maybe (die "DB_HOST is required (fail-fast)") pure
  port <- fmap (fromMaybe 8080 . (>>= readMaybeInt)) (lookupEnv "PORT")
  dbPort <- fmap (fromMaybe 5432 . (>>= readMaybeInt)) (lookupEnv "DB_PORT")
  putStrLn $ "Surypus server listening on " ++ show port ++ " (DB " ++ host ++ ":" ++ show dbPort ++ ")"
  run port (app host dbPort)

readMaybeInt :: String -> Maybe Int
readMaybeInt s = case reads s of
  [(n, "")] -> Just n
  _ -> Nothing

app :: String -> Int -> Application
app dbHost dbPort req respond = case (requestMethod req, pathInfo req) of
  ("GET", ["api", "v1", "health"]) -> do
    ok <- databaseReachable dbHost dbPort
    if ok
      then respond $ responseLBS status200 [(hContentType, "application/json")] "{\"status\":\"ok\"}"
      else respond $ responseLBS status503 [(hContentType, "application/json")] "{\"status\":\"unavailable\"}"
  ("GET", ["api", "v1"]) -> respond $ responseLBS status200 [(hContentType, "text/plain")] "Surypus API v1"
  _ -> respond $ responseLBS status404 [(hContentType, "text/plain")] (LBS.pack "not found")

databaseReachable :: String -> Int -> IO Bool
databaseReachable host port = do
  r <- timeout 1000000 $ try $ do
    addrs <- getAddrInfo (Just defaultHints {addrSocketType = Stream}) (Just host) (Just (show port))
    case addrs of
      [] -> pure False
      (a : _) -> bracket (openSocket a) close (\s -> connect s (addrAddress a) >> pure True)
  pure $ case (r :: Maybe (Either SomeException Bool)) of
    Just (Right b) -> b
    _ -> False
