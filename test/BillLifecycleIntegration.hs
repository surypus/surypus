{-# LANGUAGE OverloadedStrings #-}

-- | End-to-end bill slice through the real Servant application and PostgreSQL.
module BillLifecycleIntegration (spec) where

import Control.Exception (bracket, finally)
import Control.Monad.Logger (runNoLoggingT)
import Data.Aeson (decode, encode)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text.Encoding as TE
import Data.Int (Int64)
import Data.Time.Calendar (fromGregorian)
import qualified DAL.Pool as Pool
import DAL.Repository.RBAC (checkUserAppPermissionRepo, mkRBACRepository)
import DAL.Types (Bill (..), User (..))
import qualified Database.Persist.Sql as P
import Database.Persist.Sql (rawExecute, runSqlPool)
import Database.Persist.Postgresql (createPostgresqlPool)
import Network.HTTP.Types (Header, status200, status401)
import Network.Wai (Application, defaultRequest, pathInfo, rawPathInfo, requestHeaders, requestMethod)
import Network.Wai.Test (SRequest (..), SResponse (..), runSession, simpleStatus, srequest)
import qualified Surypus.API.Logger as Log
import qualified Surypus.API.Server as Server
import qualified Surypus.JWT.Token as JWT
import qualified Surypus.Metrics as Metrics
import System.Environment (lookupEnv, setEnv, unsetEnv)
import Test.Hspec

probeNumber :: BS.ByteString
probeNumber = "BILL-PROBE-2A5"

probeUserId :: Int64
probeUserId = 999004

probeBill :: Bill
probeBill =
  Bill
    { billId = 0
    , billCode = Just (TE.decodeUtf8 probeNumber)
    , billType = Just "sale"
    , billStatus = Just "draft"
    , billDate = fromGregorian 2026 11 27
    , billPersonId = Nothing
    , billLocationId = Nothing
    , billTotal = 120.5
    , billDiscount = 0
    , billTaxAmount = 20.5
    }

perform :: Application -> BS.ByteString -> BS.ByteString -> [Header] -> BS.ByteString -> IO SResponse
perform app method path headers body =
  runSession
    ( srequest
        ( SRequest
            defaultRequest
              { rawPathInfo = path
              , pathInfo = map TE.decodeUtf8 (filter (not . BS.null) (BC.split '/' path))
              , requestMethod = method
              , requestHeaders = ("Content-Type", "application/json") : headers
              }
            (BL.fromStrict body)
        )
    )
    app

withSecret :: IO a -> IO a
withSecret action = do
  previous <- lookupEnv "SURYPUS_JWT_SECRET"
  setEnv "SURYPUS_JWT_SECRET" "bill-lifecycle-test-secret-32-bytes-minimum"
  action `finally` maybe (unsetEnv "SURYPUS_JWT_SECRET") (setEnv "SURYPUS_JWT_SECRET") previous

setupProbe :: Pool.ConnectionPool -> IO ()
setupProbe pool = do
  runSqlPool (rawExecute "DELETE FROM bills WHERE number = ?" [P.PersistText (TE.decodeUtf8 probeNumber)]) pool
  runSqlPool (rawExecute "DELETE FROM user_role WHERE user_id = ?" [uid]) pool
  runSqlPool (rawExecute "DELETE FROM users WHERE id = ?" [uid]) pool
  runSqlPool (rawExecute "INSERT INTO users (id, username, password_hash, tenant_id) VALUES (?, 'bill_probe', 'x', 0)" [uid]) pool
  runSqlPool (rawExecute "INSERT INTO user_role (user_id, role_id) SELECT ?, id FROM role WHERE name = 'admin'" [uid]) pool
  where
    uid = P.PersistInt64 probeUserId

cleanupProbe :: Pool.ConnectionPool -> IO ()
cleanupProbe pool = do
  runSqlPool (rawExecute "DELETE FROM bills WHERE number = ?" [P.PersistText (TE.decodeUtf8 probeNumber)]) pool
  runSqlPool (rawExecute "DELETE FROM user_role WHERE user_id = ?" [P.PersistInt64 probeUserId]) pool
  runSqlPool (rawExecute "DELETE FROM users WHERE id = ?" [P.PersistInt64 probeUserId]) pool

buildApp :: Pool.ConnectionPool -> IO Application
buildApp pool = do
  logger <- Log.initLogger Log.Error
  metrics <- Metrics.initMetrics
  let repo = mkRBACRepository pool
  Server.apiServer pool logger metrics [] (checkUserAppPermissionRepo repo)

withPool :: String -> (Pool.ConnectionPool -> IO a) -> IO a
withPool url action =
  bracket (runNoLoggingT (createPostgresqlPool (BC.pack url) 2)) Pool.closePool action

spec :: Spec
spec = do
  mUrl <- runIO (lookupEnv "SURYPUS_TEST_DATABASE_URL")
  case mUrl of
    Nothing ->
      it "requires SURYPUS_TEST_DATABASE_URL" $
        pendingWith "set SURYPUS_TEST_DATABASE_URL to run the bill lifecycle integration test"
    Just url ->
      describe "bill lifecycle (real server + PostgreSQL)" $ do
        it "creates, lists, reads and posts a bill through the API" $
          withPool url $ \pool -> withSecret $ do
            setupProbe pool
            finally
              (do
                 app <- buildApp pool
                 token <- JWT.generateToken pool (User probeUserId "bill_probe" Nothing Nothing Nothing "active" 0)
                 let auth = [("Authorization", "Bearer " <> TE.encodeUtf8 token)]
                     body = BL.toStrict (encode probeBill)
                 created <- perform app "POST" "/api/v1/bills" auth body
                 simpleStatus created `shouldBe` status200
                 case decode (simpleBody created) :: Maybe Bill of
                   Nothing -> expectationFailure "create response did not decode as Bill"
                   Just bill -> billId bill `shouldSatisfy` (> 0)
                 let createdId = maybe 0 billId (decode (simpleBody created) :: Maybe Bill)
                     path = BC.pack ("/api/v1/bills/" ++ show createdId)
                 listed <- perform app "GET" "/api/v1/bills" auth BS.empty
                 simpleStatus listed `shouldBe` status200
                 BL.toStrict (simpleBody listed) `shouldSatisfy` (probeNumber `BC.isInfixOf`)
                 fetched <- perform app "GET" path auth BS.empty
                 simpleStatus fetched `shouldBe` status200
                 posted <- perform app "POST" (path <> "/post") auth BS.empty
                 simpleStatus posted `shouldBe` status200
                 after <- perform app "GET" "/api/v1/bills" auth BS.empty
                 BL.toStrict (simpleBody after) `shouldSatisfy` ("posted" `BC.isInfixOf`)
              )
              (cleanupProbe pool)

        it "rejects an unauthenticated bill read" $
          withPool url $ \pool -> do
            app <- buildApp pool
            response <- perform app "GET" "/api/v1/bills" [] BS.empty
            simpleStatus response `shouldBe` status401
