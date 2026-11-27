{-# LANGUAGE OverloadedStrings #-}

-- | Surypus server entrypoint.
--
-- Boots the real Servant application from 'Surypus.API.Server' with a
-- database-backed RBAC permission store. Configuration is fail-fast: the
-- process exits before binding the port when DB_HOST or the JWT signing
-- secret is missing.
module Main (main) where

import Control.Exception (bracket)
import Data.Maybe (fromMaybe)
import qualified DAL.Pool as Pool
import DAL.Repository.RBAC (checkUserAppPermissionRepo, mkRBACRepository)
import Network.Wai.Handler.Warp (run)
import System.Environment (lookupEnv)
import System.Exit (die)
import qualified Surypus.API.Logger as Log
import qualified Surypus.API.Server as Server
import qualified Surypus.Metrics as Metrics

main :: IO ()
main = do
  secret <- lookupEnv "SURYPUS_JWT_SECRET"
  case secret of
    Nothing -> die "SURYPUS_JWT_SECRET is required (fail-fast)"
    Just _ -> pure ()
  port <- fmap (fromMaybe 8080 . (>>= readMaybeInt)) (lookupEnv "PORT")
  pool <- Pool.createPoolFromEnv
  logger <- Log.initLogger Log.Info
  metrics <- Metrics.initMetrics
  let repository = mkRBACRepository pool
      checkPerm = checkUserAppPermissionRepo repository
      publicPaths =
        [ "/api/v1/health"
        , "/api/v1/health/db"
        , "/api/v1/metrics"
        , "/api/v1/login"
        ]
  app <- Server.apiServer pool logger metrics publicPaths checkPerm
  putStrLn $ "Surypus API listening on " ++ show port
  bracket (pure ()) (\_ -> Pool.closePool pool) (\_ -> run port app)

readMaybeInt :: String -> Maybe Int
readMaybeInt s = case reads s of
  [(n, "")] -> Just n
  _ -> Nothing

