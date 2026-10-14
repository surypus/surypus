{-# LANGUAGE OverloadedStrings #-}

module Test.Integration.PoolSpec where

import Control.Exception (SomeException, try)
import DB.Connection (PoolConfig (..), createPool)
import System.Environment (lookupEnv)
import Test.Hspec (Spec, describe, expectationFailure, hspec, it)

main :: IO ()
main = hspec spec

spec :: Spec
spec = describe "DB Pool" $ do
  it "creates pool when DB is available, otherwise marks pending" $ do
    host <- lookupEnv "DB_HOST" >>= return . maybe "localhost" id
    portS <- lookupEnv "DB_PORT" >>= return . maybe "5432" id
    user <- lookupEnv "DB_USER" >>= return . maybe "surypus" id
    password <- lookupEnv "DB_PASSWORD" >>= return . maybe "surypus" id
    database <- lookupEnv "DB_NAME" >>= return . maybe "surypus" id
    let cfg =
          PoolConfig
            { pcHost = host,
              pcPort = read portS,
              pcUser = user,
              pcPassword = password,
              pcDatabase = database,
              pcConnections = 1
            }
    res <- (try (do _ <- createPool cfg; return ()) :: IO (Either SomeException ()))
    case res of
      Left _ -> expectationFailure "DB not available"
      Right _ -> return ()
