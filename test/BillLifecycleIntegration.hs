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
import qualified Data.Text as T
import Data.Int (Int64)
import Data.Time.Calendar (fromGregorian)
import qualified DAL.Pool as Pool
import DAL.Repository.RBAC (checkUserAppPermissionRepo, mkRBACRepository)
import DAL.Types (Bill (..), User (..))
import qualified Database.Persist.Sql as P
import Database.Persist.Sql (PersistValue (..), Single (..), SqlPersistT, rawExecute, rawSql, runSqlPool)
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

countRows :: Pool.ConnectionPool -> String -> [PersistValue] -> IO Int64
countRows pool sql params = do
  rows <- (runSqlPool (rawSql (T.pack sql) params) pool :: IO [Single Int64])
  pure $ case rows of
    (Single value : _) -> value
    [] -> 0

journalTotals :: Pool.ConnectionPool -> String -> IO (Double, Double, Int64)
journalTotals pool description = do
  rows <- (runSqlPool (rawSql "SELECT COALESCE(SUM(debit),0), COALESCE(SUM(credit),0), COUNT(*) FROM journal_entries WHERE description = ?" [PersistText (T.pack description)]) pool :: IO [(Single Double, Single Double, Single Int64)])
  pure $ case rows of
    ((Single debit, Single credit, Single count) : _) -> (debit, credit, count)
    [] -> (0, 0, 0)

cleanupProbe :: Pool.ConnectionPool -> IO ()
cleanupProbe pool = do
  runSqlPool (rawExecute "DELETE FROM bills WHERE number = ?" [P.PersistText (TE.decodeUtf8 probeNumber)]) pool
  runSqlPool (rawExecute "DELETE FROM inventory_movements WHERE bill_id IN (SELECT id FROM bills WHERE number = ?)" [P.PersistText (TE.decodeUtf8 probeNumber)]) pool
  runSqlPool (rawExecute "DELETE FROM bill_posting_lines WHERE bill_id IN (SELECT id FROM bills WHERE number = ?)" [P.PersistText (TE.decodeUtf8 probeNumber)]) pool
  runSqlPool (rawExecute "DELETE FROM journal_entries WHERE description LIKE 'bill-post:%'" []) pool
  runSqlPool (rawExecute "DELETE FROM event_store WHERE aggregate_type = 'bill' AND event_type = 'bill_posted'" []) pool
  runSqlPool (rawExecute "DELETE FROM audit_log WHERE entity_type = 'bill' AND action = 'POST_BILL'" []) pool
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
                 runSqlPool (rawExecute "INSERT INTO bill_posting_lines (bill_id, goods_id, quantity) VALUES (?, 1, 2.5)" [P.PersistInt64 (fromIntegral createdId)]) pool
                 listed <- perform app "GET" "/api/v1/bills" auth BS.empty
                 simpleStatus listed `shouldBe` status200
                 BL.toStrict (simpleBody listed) `shouldSatisfy` (probeNumber `BC.isInfixOf`)
                 fetched <- perform app "GET" path auth BS.empty
                 simpleStatus fetched `shouldBe` status200
                 posted <- perform app "POST" (path <> "/post") auth BS.empty
                 simpleStatus posted `shouldBe` status200
                 let description = "bill-post:" ++ show createdId
                     billPid = P.PersistInt64 (fromIntegral createdId)
                 (debit, credit, linesCount) <- journalTotals pool description
                 linesCount `shouldBe` 2
                 debit `shouldBe` credit
                 credit `shouldBe` billTotal probeBill
                 events <- countRows pool "SELECT COUNT(*) FROM event_store WHERE aggregate_id = ? AND aggregate_type = 'bill' AND event_type = 'bill_posted'" [billPid]
                 events `shouldBe` 1
                 audits <- countRows pool "SELECT COUNT(*) FROM audit_log WHERE entity_type = 'bill' AND entity_id = ? AND action = 'POST_BILL'" [billPid]
                 audits `shouldBe` 1
                 movements <- countRows pool "SELECT COUNT(*) FROM inventory_movements WHERE bill_id = ? AND goods_id = 1 AND movement_type = 'issue' AND quantity = 2.5" [billPid]
                 movements `shouldBe` 1
                 repeated <- perform app "POST" (path <> "/post") auth BS.empty
                 simpleStatus repeated `shouldBe` status200
                 (debit2, credit2, linesCount2) <- journalTotals pool description
                 (debit2, credit2, linesCount2) `shouldBe` (debit, credit, linesCount)
                 countRows pool "SELECT COUNT(*) FROM event_store WHERE aggregate_id = ? AND aggregate_type = 'bill' AND event_type = 'bill_posted'" [billPid] `shouldReturn` 1
                 countRows pool "SELECT COUNT(*) FROM audit_log WHERE entity_type = 'bill' AND entity_id = ? AND action = 'POST_BILL'" [billPid] `shouldReturn` 1
                 countRows pool "SELECT COUNT(*) FROM inventory_movements WHERE bill_id = ?" [billPid] `shouldReturn` 1
                 missing <- perform app "POST" "/api/v1/bills/999999999/post" auth BS.empty
                 simpleStatus missing `shouldSatisfy` (/= status200)
                 countRows pool "SELECT COUNT(*) FROM event_store WHERE aggregate_id = ? AND aggregate_type = 'bill' AND event_type = 'bill_posted'" [P.PersistInt64 999999999] `shouldReturn` 0
                 after <- perform app "GET" "/api/v1/bills" auth BS.empty
                 BL.toStrict (simpleBody after) `shouldSatisfy` ("posted" `BC.isInfixOf`)
              )
              (cleanupProbe pool)

        it "rejects an unauthenticated bill read" $
          withPool url $ \pool -> do
            app <- buildApp pool
            response <- perform app "GET" "/api/v1/bills" [] BS.empty
            simpleStatus response `shouldBe` status401
