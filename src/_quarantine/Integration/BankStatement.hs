{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Bank statement import — OFX and ISO 20022 (camt.053) parsing with auto-matching
module Integration.BankStatement
  ( BankTxn  (..)
  , ImportResult  (..)
  , MatchResult  (..)
  , parseOFX
  , parseISO20022
  , importStatementLines
  , matchTransactionsToBills
  , flagUnmatchedTransactions
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, Value, encode, decode)
import GHC.Generics (Generic)
import DAL.Database (ConnectionPool, runDb)
import DAL.Types (QueryResult  (..))
import Database.Persist.Sql (PersistValue (..), Single (..), rawExecute, rawSql, SqlPersistT)

data BankTxn = BankTxn
  { btDate        :: !Text
  , btValueDate   :: !(Maybe Text)
  , btAmount      :: !Double
  , btCurrency    :: !Text
  , btDescription :: !(Maybe Text)
  , btRef         :: !(Maybe Text)
  , btCounterparty :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance ToJSON BankTxn
instance FromJSON BankTxn

data ImportResult = ImportResult
  { irImportId :: !Text
  , irRowCount :: !Int
  , irStatus   :: !Text
  } deriving (Show, Eq, Generic)

instance ToJSON ImportResult

data MatchResult = MatchResult
  { mrMatchedCount :: !Int
  , mrUnmatchedCount :: !Int
  , mrMatchedIds :: ![Text]
  } deriving (Show, Eq, Generic)

instance ToJSON MatchResult

-- | Parse OFX text into transactions.
-- OFX is SGML-like; we extract STMTTRN blocks with simple text scanning.
parseOFX :: Text -> [BankTxn]
parseOFX content =
  let blocks = extractBlocks "<STMTTRN>" "</STMTTRN>" content
  in map parseTxnBlock blocks

extractBlocks :: Text -> Text -> Text -> [Text]
extractBlocks open close txt
  | T.null txt = []
  | otherwise =
      case T.breakOn open txt of
        (_, rest) | T.null rest -> []
        (_, rest) ->
          let body = T.drop (T.length open) rest
          in case T.breakOn close body of
               (block, remaining) -> block : extractBlocks open close (T.drop (T.length close) remaining)

parseTxnBlock :: Text -> BankTxn
parseTxnBlock block = BankTxn
  { btDate        = getField "DTPOSTED" block
  , btValueDate   = Just (getField "DTAVAIL" block)
  , btAmount      = read $ T.unpack $ getField "TRNAMT" block
  , btCurrency    = "RUB"
  , btDescription = Just (getField "MEMO" block)
  , btRef         = Just (getField "FITID" block)
  , btCounterparty = Nothing
  }

getField :: Text -> Text -> Text
getField tag block =
  case T.breakOn ("<" <> tag <> ">") block of
    (_, rest) | T.null rest -> ""
    (_, rest) ->
      let val = T.drop (T.length tag + 2) rest
      in T.takeWhile (/= '<') val

-- | Parse ISO 20022 camt.053 XML into transactions.
-- Extracts Ntry/TxDtls blocks via simple text scanning.
parseISO20022 :: Text -> [BankTxn]
parseISO20022 content =
  let blocks = extractBlocks "<Ntry>" "</Ntry>" content
  in map parseNtryBlock blocks

parseNtryBlock :: Text -> BankTxn
parseNtryBlock block = BankTxn
  { btDate        = getXmlField "BookgDt" "Dt" block
  , btValueDate   = Just (getXmlField "ValDt" "Dt" block)
  , btAmount      = read $ T.unpack $ getXmlField "Amt" "" block
  , btCurrency    = "RUB"
  , btDescription = Just (getXmlField "AddtlNtryInf" "" block)
  , btRef         = Just (getXmlField "AcctSvcrRef" "" block)
  , btCounterparty = Just (getXmlField "Nm" "" block)
  }

persistTextMaybe :: Maybe Text -> PersistValue
persistTextMaybe Nothing  = PersistNull
persistTextMaybe (Just t) = PersistText t

getXmlField :: Text -> Text -> Text -> Text
getXmlField outer inner block =
  let tag = if T.null inner then outer else inner
      open = "<" <> tag <> ">"
      close = "</" <> tag <> ">"
  in case T.breakOn open block of
       (_, rest) | T.null rest -> ""
       (_, rest) ->
         let val = T.drop (T.length open) rest
         in T.takeWhile (/= '<') val

-- | Persist parsed transactions to DB under a new import record
importStatementLines :: ConnectionPool -> Text -> Text -> [BankTxn] -> IO (QueryResult ImportResult)
importStatementLines pool tenantId filename txns =
  runDb pool $ do
    -- Use rawExecute for INSERT, then get the ID via a separate query
    rawExecute
      "INSERT INTO bank_statement_import (tenant_id, filename, format, total_rows, status) \
      \VALUES (?, ?, 'OFX', ?, 'done')"
      [PersistText tenantId, PersistText filename, PersistInt64 (fromIntegral $ length txns)]
    importIds :: [Single Text] <- rawSql
      "SELECT id FROM bank_statement_import WHERE tenant_id = ? AND filename = ? ORDER BY id DESC LIMIT 1"
      [PersistText tenantId, PersistText filename]
    case importIds of
      [Single importId] -> do
        let insertLine :: BankTxn -> SqlPersistT IO ()
            insertLine t = rawExecute
              "INSERT INTO bank_statement_line \
              \(import_id, txn_date, value_date, amount, currency, description, ref_number, counterparty) \
              \VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
              [ PersistText importId
              , PersistText (btDate t)
              , persistTextMaybe (btValueDate t)
              , PersistDouble (btAmount t)
              , PersistText (btCurrency t)
              , persistTextMaybe (btDescription t)
              , persistTextMaybe (btRef t)
              , persistTextMaybe (btCounterparty t)
              ]
        mapM_ insertLine txns
        pure $ QuerySuccess $ ImportResult importId (length txns) "done"
      [] -> pure $ QueryError "Failed to create import record"
      _  -> pure $ QueryError "Multiple import records returned"

-- | Match imported transactions to existing bills by amount and date
matchTransactionsToBills :: ConnectionPool -> Text -> IO (QueryResult MatchResult)
matchTransactionsToBills pool importId =
  runDb pool $ do
    txns <- rawSql
      "SELECT id, amount, txn_date FROM bank_statement_line WHERE import_id = ?"
      [PersistText importId]
    bills <- rawSql
      "SELECT id, amount, due_date FROM bill WHERE status = 'unpaid'"
      []
    let matches = findMatches
          [(tid, amt, dt) | (Single tid, Single amt, Single dt) <- txns]
          [(bid, amt, dt) | (Single bid, Single amt, Single dt) <- bills]
    mapM_ (\(bid, txnDate) ->
      rawExecute
        "UPDATE bill SET status = 'paid', paid_date = ? WHERE id = ?"
        [PersistText txnDate, PersistText bid])
      matches
    mapM_ (\(bid, txnId) ->
      rawExecute
        "UPDATE bank_statement_line SET matched_bill_id = ? WHERE id = ?"
        [PersistText bid, PersistText txnId])
      matches
    pure $ QuerySuccess $ MatchResult
      { mrMatchedCount = length matches
      , mrUnmatchedCount = length txns - length matches
      , mrMatchedIds = map fst matches
      }

-- | Find matches between transactions and bills
findMatches :: [(Text, Double, Text)] -> [(Text, Double, Text)] -> [(Text, Text)]
findMatches txns bills =
  let matches = [(billId, txnId) |
                 (txnId, txnAmt, txnDate) <- txns,
                 (billId, billAmt, billDate) <- bills,
                 abs (txnAmt - billAmt) < 0.01,
                 txnDate == billDate]
  in matches

-- | Flag unmatched transactions for manual review
flagUnmatchedTransactions :: ConnectionPool -> Text -> IO (QueryResult ())
flagUnmatchedTransactions pool importId =
  runDb pool $ do
    rawExecute
      "UPDATE bank_statement_line SET needs_review = true \
      \WHERE import_id = ? AND matched_bill_id IS NULL"
      [PersistText importId]
    pure $ QuerySuccess ()
