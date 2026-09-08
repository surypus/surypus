{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Integrations (
    -- * Types
    IntegrationType (..),
    IntegrationStatus (..),
    Integration (..),
    BankStatement (..),
    BankTransaction (..),
    TransactionType (..),
    ImportResult (..),
    HealthCheck (..),

    -- * Bank Statement Import
    parseOFX,
    parseISO20022,
    importBankStatement,

    -- * Integration Management
    listIntegrations,
    getIntegration,
    updateIntegrationStatus,
    runHealthCheck,
) where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, try)
import Control.Monad.IO.Class (liftIO)
import DAL.Types (QueryResult (..))
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime (UTCTime), fromGregorian, getCurrentTime, secondsToDiffTime)
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Database.Persist.Sql (ConnectionPool, PersistValue (..), rawExecute, rawSql, runSqlPool, Single (..))
import GHC.Generics (Generic)

data IntegrationType
    = BankOFX
    | BankISO20022
    | PaymentGateway
    | AccountingSync
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

data IntegrationStatus
    = StatusActive
    | StatusInactive
    | StatusError Text
    | StatusMaintenance
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

data Integration = Integration
    { intId :: !Int64
    , intName :: !Text
    , intType :: !IntegrationType
    , intStatus :: !IntegrationStatus
    , intEndpoint :: !(Maybe Text)
    , intLastSync :: !(Maybe UTCTime)
    , intLastError :: !(Maybe Text)
    , intCreatedAt :: !UTCTime
    }
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

data BankStatement = BankStatement
    { bsId :: !Text
    , bsBank :: !Text
    , bsAccount :: !Text
    , bsCurrency :: !Text
    , bsDateFrom :: !UTCTime
    , bsDateTo :: !UTCTime
    , bsTransactions :: ![BankTransaction]
    , bsImportedAt :: !UTCTime
    }
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

data BankTransaction = BankTransaction
    { btId :: !Text
    , btDate :: !UTCTime
    , btType :: !TransactionType
    , btAmount :: !Double
    , btCurrency :: !Text
    , btDescription :: !Text
    , btReference :: !(Maybe Text)
    , btCounterparty :: !(Maybe Text)
    }
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

data TransactionType
    = Credit
    | Debit
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

epoch :: UTCTime
epoch = UTCTime (fromGregorian 1970 1 1) (secondsToDiffTime 0)

stripCloseTag :: Text -> Text
stripCloseTag v = case T.breakOn "</" v of
    (content, _) -> content

data ImportResult = ImportResult
    { irSuccess :: !Bool
    , irImported :: !Int
    , irSkipped :: !Int
    , irErrors :: ![Text]
    }
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

data HealthCheck = HealthCheck
    { hcIntegrationId :: !Int64
    , hcHealthy :: !Bool
    , hcLatencyMs :: !Int
    , hcMessage :: !Text
    , hcCheckedAt :: !UTCTime
    }
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

parseOFX :: Text -> Either Text BankStatement
parseOFX input =
    let lines = T.lines input
        extractField tag = fmap stripCloseTag (fmap (T.drop (T.length tag)) $ find (T.isPrefixOf tag) lines)
        find p = foldr (\x acc -> if p x then Just x else acc) Nothing
     in case (extractField "<BANKID>", extractField "<ACCTID>", extractField "<CURDEF>") of
            (Just bank, Just acct, Just currency) ->
                let txns = parseOFXTransactions lines
                 in Right $
                        BankStatement
                            { bsId = T.take 8 bank <> "-" <> T.take 8 acct
                            , bsBank = bank
                            , bsAccount = acct
                            , bsCurrency = currency
                            , bsDateFrom = epoch
                            , bsDateTo = epoch
                            , bsTransactions = txns
                            , bsImportedAt = epoch
                            }
            _ -> Left "Invalid OFX: missing required fields (BANKID, ACCTID, CURDEF)"

parseOFXTransactions :: [Text] -> [BankTransaction]
parseOFXTransactions = go []
  where
    go acc [] = reverse acc
    go acc (line : rest)
        | "<STMTTRN>" `T.isPrefixOf` line =
            let (txnLines, remaining) = break (T.isSuffixOf "</STMTTRN>") rest
                txn = parseSingleOFXTransaction (line : txnLines)
             in case txn of
                    Just t -> go (t : acc) remaining
                    Nothing -> go acc remaining
        | otherwise = go acc rest

parseSingleOFXTransaction :: [Text] -> Maybe BankTransaction
parseSingleOFXTransaction lines =
  let extract tag = fmap stripCloseTag (fmap (T.drop (T.length tag)) $ find (T.isPrefixOf tag) lines)
      find p = foldr (\x acc -> if p x then Just x else acc) Nothing
      trntype = extract "<TRNTYPE>"
      amountStr = extract "<TRNAMT>"
      amount = amountStr >>= \s -> case reads (T.unpack s) of
        (x, _):_ -> Just x
        [] -> Nothing
      name = extract "<NAME>"
      memo = extract "<MEMO>"
  in case trntype of
       Just _ -> Just $ BankTransaction
          { btId = fromMaybe "unknown" (extract "<DTPOSTED")
          , btDate = epoch
          , btType = if trntype == Just "CREDIT" then Credit else Debit
          , btAmount = fromMaybe 0 amount
          , btCurrency = "USD"
          , btDescription = fromMaybe "" (name <|> memo)
          , btReference = extract "<REFNUM"
          , btCounterparty = extract "<PAYEEID"
          }
       Nothing -> Nothing

parseISO20022 :: Text -> Either Text BankStatement
parseISO20022 input =
    if "<Document" `T.isPrefixOf` T.dropWhile (== ' ') input
        then
            Right $
                BankStatement
                    { bsId = "iso20022-import"
                    , bsBank = "Unknown"
                    , bsAccount = "Unknown"
                    , bsCurrency = "USD"
                    , bsDateFrom = epoch
                    , bsDateTo = epoch
                    , bsTransactions = []
                    , bsImportedAt = epoch
                    }
        else Left "Invalid ISO 20022: missing Document element"

importBankStatement :: IntegrationType -> Text -> IO ImportResult
importBankStatement itype content = do
    let result = case itype of
            BankOFX -> parseOFX content
            BankISO20022 -> parseISO20022 content
            _ -> Left "Unsupported integration type for bank import"
    now <- getCurrentTime
    case result of
        Left err -> pure $ ImportResult False 0 0 [err]
        Right stmt ->
            pure $
                ImportResult
                    { irSuccess = True
                    , irImported = length (bsTransactions stmt)
                    , irSkipped = 0
                    , irErrors = []
                    }

parseIntegrationType :: Text -> IntegrationType
parseIntegrationType "BankOFX" = BankOFX
parseIntegrationType "BankISO20022" = BankISO20022
parseIntegrationType "PaymentGateway" = PaymentGateway
parseIntegrationType "AccountingSync" = AccountingSync
parseIntegrationType _ = BankOFX

parseIntegrationStatus :: Text -> IntegrationStatus
parseIntegrationStatus "StatusActive" = StatusActive
parseIntegrationStatus "StatusInactive" = StatusInactive
parseIntegrationStatus "StatusMaintenance" = StatusMaintenance
parseIntegrationStatus other = StatusError other

parseUTCTime :: Text -> Maybe UTCTime
parseUTCTime t = parseTimeM True defaultTimeLocale "%FT%T%Q%z" (T.unpack t)
           <|> parseTimeM True defaultTimeLocale "%FT%T%QZ" (T.unpack t)

integrationFromRow :: (Single Int64, Single Text, Single Text, Single Text, Single (Maybe Text), Single (Maybe Text), Single (Maybe Text), Single (Maybe Text)) -> Integration
integrationFromRow (Single i, Single n, Single t, Single s, Single e, Single ls, Single le, Single ca) =
    Integration
        { intId = i
        , intName = n
        , intType = parseIntegrationType t
        , intStatus = parseIntegrationStatus s
        , intEndpoint = e
        , intLastSync = ls >>= parseUTCTime
        , intLastError = le
        , intCreatedAt = fromMaybe epoch (ca >>= parseUTCTime)
        }

listIntegrations :: ConnectionPool -> IO (QueryResult [Integration])
listIntegrations pool = do
    rows <- liftIO $ runSqlPool
        (rawSql
            "SELECT id, name, integration_type, status, endpoint, last_sync::TEXT, last_error, created_at::TEXT FROM integrations ORDER BY name"
            [])
        pool
    return $ QuerySuccess (map integrationFromRow rows)

getIntegration :: ConnectionPool -> Int64 -> IO (QueryResult Integration)
getIntegration pool intId = do
    rows <- liftIO $ runSqlPool
        (rawSql
            "SELECT id, name, integration_type, status, endpoint, last_sync::TEXT, last_error, created_at::TEXT FROM integrations WHERE id = ?"
            [PersistInt64 intId])
        pool
    case rows of
        (row:_) -> return $ QuerySuccess (integrationFromRow row)
        _ -> return $ QueryError "Not Found"

updateIntegrationStatus :: ConnectionPool -> Int64 -> IntegrationStatus -> IO (QueryResult ())
updateIntegrationStatus pool intId status = do
    let statusText = case status of
            StatusActive -> "StatusActive"
            StatusInactive -> "StatusInactive"
            StatusMaintenance -> "StatusMaintenance"
            StatusError _ -> "StatusInactive"
    liftIO $ runSqlPool
        (rawExecute
            "UPDATE integrations SET status = ?, last_error = CASE WHEN ? = 'StatusError' THEN ? ELSE last_error END WHERE id = ?"
            [PersistText statusText, PersistText statusText, PersistNull, PersistInt64 intId])
        pool
    return $ QuerySuccess ()

runHealthCheck :: Int64 -> IO HealthCheck
runHealthCheck intId = do
    now <- getCurrentTime
    result <- try (pure ()) :: IO (Either SomeException ())
    case result of
        Right _ -> pure $ HealthCheck intId True 0 "OK" now
        Left e -> pure $ HealthCheck intId False 0 (T.pack $ show e) now
