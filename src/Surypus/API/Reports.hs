{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.Reports (
    Report (..),
    ReportExportRequest (..),
    ReportExportResponse (..),
    generateReport,
    generateReportPdf,
    serveReportFile,
    getPnLReport,
    getInventoryReport,
) where

import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import DAL.Types (QueryResult (..))
import Data.Aeson (FromJSON, ToJSON, object, (.=))
import qualified Data.Aeson as Aeson
import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString as BS
import Data.IORef (IORef, newIORef, readIORef, atomicModifyIORef')
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (formatTime, defaultTimeLocale)
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUIDv4
import Database.Persist.Sql (ConnectionPool, rawSql, runSqlPool, Single (..))
import GHC.Generics (Generic)
import qualified Network.HTTP.Types as HT
import Network.Wai (Application, responseFile, responseLBS)
import System.Directory (createDirectoryIfMissing, doesFileExist, removeFile)
import System.Exit (ExitCode (..))
import System.IO (hClose)
import System.IO.Temp (openTempFile)
import System.IO.Unsafe (unsafePerformIO)
import System.Process (readProcessWithExitCode)

data Report = Report
    { rptName :: !Text
    , rptData :: !Text
    }
    deriving (Show, Eq, Generic)

instance ToJSON Report

data ReportExportRequest = ReportExportRequest
    { rerReportType :: !Text
    , rerFormat     :: !Text
    } deriving (Show, Eq, Generic)
instance FromJSON ReportExportRequest

data ReportExportResponse = ReportExportResponse
    { rerDownloadUrl :: !Text
    , rerStatus      :: !Text
    } deriving (Show, Eq, Generic)
instance ToJSON ReportExportResponse

data PnLRow = PnLRow
    { pnlRevenue :: !Double
    , pnlCogs :: !Double
    , pnlIncome :: !Double
    , pnlExpenses :: !Double
    }
    deriving (Show, Eq, Generic)

instance ToJSON PnLRow

data InvItem = InvItem
    { invName :: !Text
    , invCode :: !Text
    , invQty :: !Double
    , invUnitCost :: !Double
    , invTotalValue :: !Double
    }
    deriving (Show, Eq, Generic)

instance ToJSON InvItem

{-# NOINLINE reportFilesRef #-}
reportFilesRef :: IORef (Map Text FilePath)
reportFilesRef = unsafePerformIO $ newIORef Map.empty

generateReport :: ConnectionPool -> Text -> IO (QueryResult Report)
generateReport pool reportName = case reportName of
    "pnl" -> getPnLReport pool
    "inventory" -> getInventoryReport pool
    _ -> return $ QuerySuccess (Report reportName "{}")

getPnLReport :: ConnectionPool -> IO (QueryResult Report)
getPnLReport pool = do
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT \
            \  COALESCE((SELECT SUM(total_amount) FROM bill WHERE doc_date >= date_trunc('month', CURRENT_DATE)), 0), \
            \  COALESCE((SELECT SUM(qtty * unit_cost) FROM stock_movement \
            \             WHERE movement_date >= date_trunc('month', CURRENT_DATE)), 0), \
            \  COALESCE((SELECT SUM(total_amount) FROM bill WHERE doc_date >= date_trunc('month', CURRENT_DATE) \
            \             AND total_amount > 0), 0), \
            \  COALESCE((SELECT SUM(total_amount) FROM bill WHERE doc_date >= date_trunc('month', CURRENT_DATE) \
            \             AND total_amount < 0), 0)"
            []) pool
    case result of
        [(Single (revenue :: Double), Single (cogs :: Double), Single (income :: Double), Single (expenses :: Double))] -> do
            let jsonData =
                    decodeUtf8 . BL.toStrict $
                        Aeson.encode $
                            object
                                [ "revenue" .= revenue
                                , "costOfGoodsSold" .= cogs
                                , "grossProfit" .= (revenue - cogs)
                                , "totalIncome" .= income
                                , "totalExpenses" .= (abs expenses)
                                , "netProfit" .= (income - abs expenses)
                                , "currency" .= ("RUB" :: Text)
                                ]
            return $ QuerySuccess (Report "P&L Statement" jsonData)
        _ -> return $ QuerySuccess (Report "P&L Statement" "{}")

getInventoryReport :: ConnectionPool -> IO (QueryResult Report)
getInventoryReport pool = do
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT g.name, g.code, COALESCE(s.qtty, 0), \
            \  COALESCE(s.unit_cost, 0), \
            \  COALESCE(s.qtty * s.unit_cost, 0) \
            \FROM goods g \
            \LEFT JOIN stock s ON s.goods_id = g.id \
            \ORDER BY g.name"
            []) pool
    let rows = [ InvItem name code qty unitCost totalValue
               | (Single (name :: Text), Single (code :: Text), Single (qty :: Double), Single (unitCost :: Double), Single (totalValue :: Double)) <- result
               ]
    let totalValue = sum (map invTotalValue rows)
    let jsonData =
            decodeUtf8 . BL.toStrict $
                Aeson.encode $
                    object
                        [ "items" .= rows
                        , "totalValue" .= totalValue
                        , "itemCount" .= length rows
                        , "currency" .= ("RUB" :: Text)
                        ]
    return $ QuerySuccess (Report "Inventory Report" jsonData)

reportToHtml :: Text -> Text -> Text -> Text
reportToHtml rptType ts jsonData =
    let title = if rptType == "pnl" then "Отчёт о прибылях и убытках" else "Инвентаризационная опись"
    in T.concat
    [ "<!DOCTYPE html><html><head><meta charset='utf-8'><title>"
    , title
    , "</title><style>"
    , "body{font-family:DejaVu Sans,sans-serif;margin:40px;font-size:12px;}"
    , "h1{color:#1a237e;font-size:18px;border-bottom:2px solid #1a237e;padding-bottom:8px;}"
    , "table{width:100%;border-collapse:collapse;margin-top:16px;}"
    , "th{background:#1a237e;color:#fff;padding:8px;text-align:left;font-size:11px;}"
    , "td{padding:6px 8px;border-bottom:1px solid #e0e0e0;}"
    , "tr:nth-child(even){background:#f5f5f5;}"
    , ".total{font-weight:bold;background:#e8eaf6 !important;}"
    , ".meta{color:#666;font-size:11px;margin-top:4px;}"
    , ".footer{position:fixed;bottom:0;width:100%;text-align:center;color:#999;font-size:10px;border-top:1px solid #eee;padding-top:4px;}"
    , "</style></head><body>"
    , "<h1>", title, "</h1>"
    , "<p class='meta'>Сформировано: ", ts, "</p>"
    , "<pre style='white-space:pre-wrap;font-family:DejaVu Sans Mono,monospace;font-size:11px;'>"
    , jsonData
    , "</pre>"
    , "<div class='footer'>Сурьпус — Формально верифицированные бизнес-операции</div>"
    , "</body></html>"
    ]

generateReportPdf :: ConnectionPool -> Text -> IO (Either Text Text)
generateReportPdf pool rptType = do
    result <- generateReport pool rptType
    case result of
        QueryError e -> return $ Left e
        QuerySuccess rpt -> do
            now <- getCurrentTime
            let ts = T.pack $ formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S" now
                html = reportToHtml rptType ts (rptData rpt)
            let outDir = "/tmp/surypus-reports"
            createDirectoryIfMissing True outDir
            (tmpPath, tmpHandle) <- openTempFile "/tmp" "surypus-XXXXXX.html"
            BS.hPut tmpHandle (encodeUtf8 html)
            hClose tmpHandle
            uuid <- UUID.toText <$> UUIDv4.nextRandom
            let pdfPath = outDir <> "/" <> T.unpack uuid <> ".pdf"
            (exitCode, _stdout, stderr) <- readProcessWithExitCode
                "weasyprint" [tmpPath, pdfPath] ""
            doesFileExist tmpPath >>= \exists -> when exists $ removeFile tmpPath
            case exitCode of
                ExitSuccess -> do
                    atomicModifyIORef' reportFilesRef $ \m -> (Map.insert uuid pdfPath m, ())
                    return $ Right (T.concat [uuid, ".pdf"])
                ExitFailure _ ->
                    return $ Left (T.pack $ "PDF generation failed: " <> stderr)

serveReportFile :: Text -> Application
serveReportFile filename req respond = do
    refMap <- readIORef reportFilesRef
    let uuid = T.replace ".pdf" "" filename
    case Map.lookup uuid refMap of
        Nothing -> respond $ responseLBS HT.status404 [("Content-Type", "text/plain")] "Report not found"
        Just filePath -> do
            exists <- doesFileExist filePath
            if exists
                then respond $ responseFile HT.status200
                    [("Content-Type", "application/pdf")
                    ,("Content-Disposition", BS.concat ["attachment; filename=\"", encodeUtf8 filename, "\""])]
                    filePath Nothing
                else respond $ responseLBS HT.status404 [("Content-Type", "text/plain")] "Report file expired"
