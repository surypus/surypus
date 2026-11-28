{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Bill posting with its accounting, event and audit side effects.
--
-- All writes happen on one PostgreSQL connection inside an explicit
-- transaction. A failure rolls back the entire posting; a second posting of
-- an already-posted bill is a no-op.
module Service.BillPosting (postBillWithEffects) where

import Control.Exception (SomeException)
import Control.Monad.Catch (throwM, try)
import Control.Monad (forM_)
import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import DAL.Database (ConnectionPool, runDb)
import DAL.Types (QueryResult (..))
import Database.Persist.Sql (PersistValue (..), Single (..), SqlPersistT, rawExecute, rawSql)

billNotFound :: Text
billNotFound = "Bill not found"

postBillWithEffects :: ConnectionPool -> Int64 -> IO (QueryResult ())
postBillWithEffects pool billId = do
  outcome <- try $ runDb pool $ do
    rawExecute "BEGIN" []
    result <- (try (postInside billId) :: SqlPersistT IO (Either SomeException ()))
    case result of
      Right () -> rawExecute "COMMIT" []
      Left (err :: SomeException) -> do
        rawExecute "ROLLBACK" []
        throwM err
  pure $ case outcome of
    Right () -> QuerySuccess ()
    Left (err :: SomeException) -> QueryError (T.pack (show err))

postInside :: Int64 -> SqlPersistT IO ()
postInside billId = do
  statuses <-
    rawSql
      "SELECT COALESCE(status, '') FROM bills WHERE id = ?"
      [PersistInt64 billId] ::
      SqlPersistT IO [Single Text]
  case statuses of
    [] -> throwM (userError (T.unpack billNotFound))
    [Single "posted"] -> pure ()
    _ -> do
      totals <-
        rawSql
          "SELECT COALESCE(total_amount, 0) FROM bills WHERE id = ?"
          [PersistInt64 billId] ::
          SqlPersistT IO [Single Double]
      let total = case totals of
            (Single amount : _) -> amount
            [] -> 0
          description = "bill-post:" <> T.pack (show billId)
      rawExecute
        "INSERT INTO journal_entries (debit, credit, amount, posted, description) VALUES (?, 0, ?, TRUE, ?)"
        [PersistDouble total, PersistDouble total, PersistText description]
      rawExecute
        "INSERT INTO journal_entries (debit, credit, amount, posted, description) VALUES (0, ?, ?, TRUE, ?)"
        [PersistDouble total, PersistDouble total, PersistText description]
      sequences <-
        rawSql
          "SELECT COALESCE(MAX(sequence_number), 0) + 1 FROM event_store WHERE aggregate_id = ? AND aggregate_type = 'bill'"
          [PersistInt64 billId] ::
          SqlPersistT IO [Single Int64]
      let sequenceNumber = case sequences of
            (Single value : _) -> value
            [] -> 1
          eventData = "{\"bill_id\":" <> T.pack (show billId) <> "}" :: Text
      lineRows <-
        rawSql
          "SELECT goods_id, quantity FROM bill_posting_lines WHERE bill_id = ?"
          [PersistInt64 billId] ::
          SqlPersistT IO [(Single Int64, Single Double)]
      forM_ lineRows $ \(Single goodsId, Single quantity) ->
        rawExecute
          "INSERT INTO inventory_movements (bill_id, goods_id, movement_type, quantity) VALUES (?, ?, 'issue', ?)"
          [PersistInt64 billId, PersistInt64 goodsId, PersistDouble quantity]
      rawExecute
        "INSERT INTO event_store (id, aggregate_id, aggregate_type, event_type, event_version, event_schema_version, event_data, event_metadata, sequence_number, occurred_at, created_at) VALUES (gen_random_uuid(), ?, 'bill', 'bill_posted', 1, 1, ?::jsonb, '{}'::jsonb, ?, NOW(), NOW())"
        [PersistInt64 billId, PersistText eventData, PersistInt64 sequenceNumber]
      rawExecute
        "INSERT INTO audit_log (username, action, entity_type, entity_id, description) VALUES ('system', 'POST_BILL', 'bill', ?, ?)"
        [PersistInt64 billId, PersistText description]
      rawExecute
        "UPDATE bills SET status = 'posted' WHERE id = ?"
        [PersistInt64 billId]
