{-# LANGUAGE OverloadedStrings #-}

-- | Job processing must never report success for work that was not done.
module DAL.QueueSpec (spec) where

import Control.Exception (bracket)
import Control.Monad.Logger (runNoLoggingT)
import Data.Aeson (Value (Null))
import Data.ByteString.Char8 (pack)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime, getCurrentTime)
import DAL.Pool (ConnectionPool, closePool)
import DAL.Queue (Job (..), JobResult (..), JobStatus (..), JobType (..), processJob)
import Database.Persist.Postgresql (createPostgresqlPool)
import Test.Hspec

allTypes :: [JobType]
allTypes =
  [ BillPosting
  , InventoryReceipt
  , InventoryIssue
  , ReportGeneration
  , DataExport
  , DataImport
  , EmailNotification
  , CustomJob "custom"
  ]

mkJob :: UTCTime -> JobType -> Job
mkJob now jobType' =
  Job
    { jobId = "job-1" :: Text
    , jobType = jobType'
    , jobStatus = JobPending
    , jobPayload = Null
    , jobPriority = 0
    , jobRetryCount = 0
    , jobMaxRetries = 3
    , jobCreatedAt = now
    , jobScheduledAt = Nothing
    , jobProcessedAt = Nothing
    , jobCompletedAt = Nothing
    , jobError = Nothing
    , jobResult = Nothing
    }

-- Pool creation is lazy; processJob makes no query for unhandled types.
withPool :: (ConnectionPool -> IO a) -> IO a
withPool action =
  bracket
    (runNoLoggingT $ createPostgresqlPool (pack "host=127.0.0.1 port=1 dbname=x user=x password=x") 1)
    closePool
    action

spec :: Spec
spec = around withPool $ describe "DAL.Queue processJob (fail-closed)" $ do
  it "never reports a placeholder job as completed" $ \pool -> do
    now <- getCurrentTime
    results <- mapM (processJob pool . mkJob now) allTypes
    mapM_ (\r -> jobResultStatus r `shouldBe` JobFailed) results

  it "gives an explicit reason for every unhandled type" $ \pool -> do
    now <- getCurrentTime
    results <- mapM (processJob pool . mkJob now) allTypes
    mapM_
      ( \r ->
          jobResultError r `shouldSatisfy` maybe False (T.isInfixOf "no real handler")
      )
      results

  it "does not fabricate result data or completion time" $ \pool -> do
    now <- getCurrentTime
    result <- processJob pool (mkJob now BillPosting)
    jobResultData result `shouldBe` Nothing
    jobResultCompletedAt result `shouldBe` Nothing
