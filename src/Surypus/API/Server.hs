{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.Server (apiServer) where

import Control.Monad.IO.Class (liftIO)
import qualified DAL.Mutations
import qualified DAL.QueriesORM
import qualified DAL.Types as DAL
import DAL.Pool (ConnectionPool)
import Crypto.Hash (hash, SHA256)
import Data.ByteString (ByteString)
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as DT
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as LBS
import Data.Maybe (fromMaybe)
import System.Process (readProcess)
import Data.Time.Calendar (Day, fromGregorian)
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUIDv4
import Database.Persist.Sql (runSqlPool, rawSql, Single(..))
import qualified Service.PayrollService as PR
import Database.Persist.PersistValue (PersistValue(..))
import GHC.Generics (Generic)
import Network.HTTP.Types (status200, status401, status503)
import Network.Wai as W
import Network.Wai.Handler.WebSockets (websocketsOr)
import qualified Network.WebSockets as NetWS
import qualified Surypus.API.RateLimiter as RL (RateLimiterConfig(..), RateLimiterState, defaultRateLimiterConfig, initRateLimiter, rateLimiterMiddleware)
import Servant
import Surypus (
     Bill (..),
     BillInput (..),
     Goods (..),
     MutationResult (..),
     Payment (..),
     PaymentInput (..),
     Person (..),
     QueryResult (..),
     User (..),
     UserInput (..)
    )
import qualified Surypus.API.Accounting as Accounting
import qualified Surypus.API.BillTemplates as BillTemplates
import qualified Surypus.API.Bills as Bills
import qualified Surypus.API.CRM as CRM
import qualified Surypus.API.Classifiers as Classifiers
import qualified Surypus.API.Dashboard as Dashboard
import qualified Surypus.API.Goods as Goods
import qualified Surypus.API.Integrations as Integrations
import qualified Surypus.API.Logger as Log
import qualified Surypus.API.Notifications as Notifications
import qualified Surypus.API.Orders as Orders
import qualified Surypus.API.Push as Push
import qualified Surypus.API.Payment as Payments
import qualified Surypus.API.Payroll as Payroll
import qualified Surypus.API.Persons as Persons
import qualified Surypus.API.Reports as Reports
import qualified Surypus.API.Stock as StockAPI
import qualified Surypus.API.Workflow as Workflow
import qualified Surypus.API.GraphQL as GraphQL
import qualified Surypus.JWT.Token as JWT
import qualified Surypus.WebSocket as WS
import Surypus.API.AuthMiddleware (withAuthzResolverAdvanced)
import Surypus.API.MetricsMiddleware (MetricsMiddlewareConfig(..), withMetricsCollection)
import Surypus.Metrics (Metrics, renderPrometheus)
import qualified MultiTenancy.Middleware as MT


-- Local type definitions for API
data PayrollCalcRequest = PayrollCalcRequest
  { pcrEmployeeId :: Int64
  , pcrTenantId :: Int64
  , pcrPeriod :: Day
  , pcrBaseSalary :: Double
  , pcrBonus :: Double
  , pcrDaysWorked :: Int
  , pcrVacationDays :: Int
  , pcrSickDays :: Int
  , pcrUserId :: Int64
  } deriving (Generic, Show, Eq)
instance FromJSON PayrollCalcRequest

data LoginRequest = LoginRequest
    { lrUsername :: Text
    , lrPassword :: Text
    }
    deriving (Generic, Show, Eq)
instance FromJSON LoginRequest

data LoginResponse = LoginResponse
    { lAccessToken :: Text
    , lRefreshToken :: Maybe Text
    , lUserId :: Int64
    , lExpiresIn :: Int
    }
    deriving (Generic, Show, Eq)
instance ToJSON LoginResponse

data RegisterRequest = RegisterRequest
    { rrUsername :: Text
    , rrPassword :: Text
    , rrEmail :: Maybe Text
    }
    deriving (Generic, Show, Eq)
instance FromJSON RegisterRequest

data UserInfoResponse = UserInfoResponse
    { uirId :: Int64
    , uirUsername :: Text
    , uirEmail :: Maybe Text
    }
    deriving (Generic, Show, Eq)
instance ToJSON UserInfoResponse

data AuditLogEntry = AuditLogEntry
  { aleId :: Int64, aleUserId :: Int64, aleAction :: Text, aleResourceType :: Text
  , aleResourceId :: Int64, aleOldValues :: Maybe Text, aleNewValues :: Maybe Text
  , aleIpAddress :: Text, aleCreatedAt :: Text
  } deriving (Generic, Show, Eq)
instance FromJSON AuditLogEntry
instance ToJSON AuditLogEntry

data RoleEntry = RoleEntry
  { reId :: Int64, reName :: Text
  } deriving (Generic, Show, Eq)
instance FromJSON RoleEntry
instance ToJSON RoleEntry

data RoleInput = RoleInput
  { riName :: Text
  } deriving (Generic, Show, Eq)
instance FromJSON RoleInput

data PermissionEntry = PermissionEntry
  { peId :: Int64, peName :: Text
  } deriving (Generic, Show, Eq)
instance FromJSON PermissionEntry
instance ToJSON PermissionEntry

data Env = Env
     { envConnectionPool :: ConnectionPool
     , envLogger :: Log.Logger
     , envMetrics :: Metrics
     , envWSHandler :: Maybe WS.WebSocketHandler
     , envPushStore :: Push.PushStore
     }

correlationMiddleware :: Log.Logger -> Application -> Application
correlationMiddleware logger app req respond = do
    let corrIdHeader = lookup "x-correlation-id" (W.requestHeaders req)
    corrId <- case corrIdHeader of
        Just cid -> return (TE.decodeUtf8 cid)
        Nothing -> UUID.toText <$> UUIDv4.nextRandom
    Log.withCorrelationId logger (DT.unpack corrId) $ app req respond

authMiddleware :: Application -> Application
authMiddleware app req respond = do
    let path = W.rawPathInfo req
    if path == "/api/v1/login"
        then app req respond
        else case lookup "Authorization" (W.requestHeaders req) of
            Nothing -> respond $ W.responseLBS status401 [("Content-Type", "text/plain")] "Unauthorized"
            Just hdr -> do
                let hdrStr = TE.decodeUtf8 hdr
                case DT.stripPrefix "Bearer " hdrStr of
                    Nothing -> respond $ W.responseLBS status401 [("Content-Type", "text/plain")] "Invalid authorization header format"
                    Just tok ->
                        JWT.verifyToken tok >>= \case
                            Left _ -> respond $ W.responseLBS status401 [("Content-Type", "text/plain")] "Invalid token"
                            Right _ -> app req respond

apiServer :: ConnectionPool -> Log.Logger -> Metrics -> [Text] -> (Int64 -> Text -> IO Bool) -> IO Application
apiServer connPool logger metrics publicPaths checkPermission = do
    let rlConfig = RL.defaultRateLimiterConfig
    rlState <- RL.initRateLimiter rlConfig
    wsHandler <- WS.initWebSocketHandler
    pushStore <- Push.newPushStore
    let metricsCfg = MetricsMiddlewareConfig metrics publicPaths
        env = Env connPool logger metrics (Just wsHandler) pushStore
        wsApp pending = do
            let path = NetWS.requestPath (NetWS.pendingRequest pending)
            if path == "/api/v1/ws"
                then do
                    conn <- NetWS.acceptRequest pending
                    WS.handleWebSocket wsHandler conn
                else
                    NetWS.rejectRequest pending "Not a WebSocket request"
        servantApp = metricsEndpoint metrics
            $ RL.rateLimiterMiddleware rlConfig rlState
            $ withMetricsCollection metricsCfg
            $ correlationMiddleware logger
            $ MT.tenantMiddleware
            $ authMiddleware
            $ withAuthzResolverAdvanced publicPaths checkPermission
            $ serve (Proxy @SurypusApi) (server env)
        baseApp = healthEndpoint connPool servantApp
    return $ websocketsOr NetWS.defaultConnectionOptions wsApp baseApp

healthEndpoint :: ConnectionPool -> Application -> Application
healthEndpoint connPool app req respond =
    case W.rawPathInfo req of
        "/api/v1/health" -> do
            respond $ W.responseLBS status200 [("Content-Type", "text/plain")] "OK"
        "/api/v1/health/db" -> do
            result <- runSqlPool (rawSql "SELECT 1 as health" []) connPool
            case result of
                [Single (1 :: Int64)] -> respond $ W.responseLBS status200 [("Content-Type", "text/plain")] "DB OK"
                _ -> respond $ W.responseLBS status503 [("Content-Type", "text/plain")] "DB ERROR"
        path -> do
            let pathStr = TE.decodeUtf8 path
            if "/api/v1/reports/download/" `DT.isPrefixOf` pathStr
                then do
                    let filename = DT.replace "/api/v1/reports/download/" "" pathStr
                    Reports.serveReportFile filename req respond
                else app req respond

metricsEndpoint :: Metrics -> Application -> Application
metricsEndpoint metrics app req respond =
    if W.rawPathInfo req == "/api/v1/metrics"
        then do
            promText <- renderPrometheus metrics
            respond $ W.responseLBS status200
                [("Content-Type", "text/plain; charset=utf-8")]
                (LBS.encodeUtf8 (TL.fromStrict promText))
        else app req respond

-- ── API type ────────────────────────────────────────────────────────────────

type SurypusApi =
    "api"
        :> "v1"
        :> ( "login" :> ReqBody '[JSON] LoginRequest :> Post '[JSON] LoginResponse
                :<|> "register" :> ReqBody '[JSON] RegisterRequest :> Post '[JSON] LoginResponse
                :<|> "auth" :> "me" :> Header "Authorization" Text :> Get '[JSON] UserInfoResponse
                -- GraphQL endpoint
                :<|> "graphql" :> GraphQL.GraphQLAPI
                -- Bills
                :<|> "bills" :> Get '[JSON] [Bill]
                :<|> "bills" :> ReqBody '[JSON] BillInput :> Post '[JSON] Bill
                :<|> "bills" :> Capture "id" Int64 :> Get '[JSON] Bill
                :<|> "bills" :> Capture "id" Int64 :> "post" :> Post '[JSON] ()
                :<|> "bills" :> Capture "id" Int64 :> "status" :> QueryParam "status" Int :> Put '[JSON] ()
                :<|> "bills" :> Capture "id" Int64 :> Delete '[JSON] ()
                -- Bill templates
                :<|> "bill-templates" :> Get '[JSON] [BillTemplates.BillTemplateInfo]
                :<|> "bill-templates" :> QueryParam "name" Text :> QueryParam "content" Text :> Post '[JSON] MutationResult
                :<|> "bill-templates" :> Capture "id" Int64 :> Delete '[JSON] ()
                -- Goods / Persons / Payments
                :<|> "goods" :> Get '[JSON] [Goods]
                :<|> "persons" :> Get '[JSON] [Person]
                :<|> "payments" :> Get '[JSON] [Payment]
                :<|> "payments" :> ReqBody '[JSON] PaymentInput :> Post '[JSON] MutationResult
                :<|> "payments" :> Capture "id" Int64 :> Get '[JSON] Payment
                :<|> "payments" :> Capture "id" Int64 :> ReqBody '[JSON] PaymentInput :> Put '[JSON] Payment
                :<|> "payments" :> Capture "id" Int64 :> Delete '[JSON] ()
                :<|> "payments" :> "aging" :> Get '[JSON] [Payments.PaymentAgingRow]
                -- Dashboard
                :<|> "dashboard" :> Get '[JSON] Dashboard.DashboardKPI
                :<|> "dashboard" :> "revenue" :> Get '[JSON] [Dashboard.RevenuePoint]
                :<|> "dashboard" :> "orders" :> Get '[JSON] [Dashboard.OrderStatus]
                :<|> "dashboard" :> "stock" :> Get '[JSON] [Dashboard.StockSummary]
                -- CRM
                :<|> "crm" :> "deals" :> Get '[JSON] [CRM.Deal]
                :<|> "crm" :> "deals" :> ReqBody '[JSON] CRM.DealInput :> Post '[JSON] CRM.Deal
                :<|> "crm" :> "deals" :> Capture "id" Text :> Get '[JSON] CRM.Deal
                :<|> "crm" :> "deals" :> Capture "id" Text :> "stage" :> Capture "stageId" Text :> Post '[JSON] CRM.Deal
                :<|> "crm" :> "pipeline" :> Get '[JSON] [CRM.PipelineForecast]
                :<|> "crm" :> "deals" :> Capture "id" Text :> "activities" :> Get '[JSON] [CRM.Activity]
                :<|> "crm" :> "contacts" :> Get '[JSON] [CRM.Contact]
                :<|> "crm" :> "contacts" :> ReqBody '[JSON] CRM.ContactInput :> Post '[JSON] CRM.Contact
                :<|> "crm" :> "contacts" :> Capture "id" Text :> Get '[JSON] CRM.Contact
                :<|> "crm" :> "contacts" :> Capture "id" Text :> ReqBody '[JSON] CRM.ContactInput :> Put '[JSON] CRM.Contact
                :<|> "crm" :> "contacts" :> Capture "id" Text :> "delete" :> Post '[JSON] ()
                :<|> "crm" :> "contacts" :> "search" :> Capture "q" Text :> Get '[JSON] [CRM.Contact]
                :<|> "crm" :> "companies" :> Get '[JSON] [CRM.Company]
                :<|> "crm" :> "companies" :> ReqBody '[JSON] CRM.CompanyInput :> Post '[JSON] CRM.Company
                :<|> "crm" :> "companies" :> Capture "id" Text :> Get '[JSON] CRM.Company
                :<|> "crm" :> "companies" :> Capture "id" Text :> ReqBody '[JSON] CRM.CompanyInput :> Put '[JSON] CRM.Company
                :<|> "crm" :> "companies" :> Capture "id" Text :> "delete" :> Post '[JSON] ()
                :<|> "crm" :> "companies" :> "search" :> Capture "q" Text :> Get '[JSON] [CRM.Company]
                :<|> "crm" :> "pipeline" :> "stages" :> Get '[JSON] [CRM.PipelineStage]
                :<|> "crm" :> "pipeline" :> "stages" :> Capture "id" Text :> "rules" :> Get '[JSON] [CRM.StageRule]
                :<|> "crm" :> "pipeline" :> "forecast" :> "refresh" :> Post '[JSON] ()
                :<|> "crm" :> "deals" :> Capture "id" Text :> "history" :> Get '[JSON] [CRM.StageTransition]
                -- Notifications
                :<|> "notifications" :> Get '[JSON] [Notifications.Notification]
                :<|> "notifications" :> ReqBody '[JSON] Notifications.NotificationInput :> Post '[JSON] Notifications.Notification
                :<|> "notifications" :> Capture "id" Text :> "read" :> Post '[JSON] ()
                :<|> "notifications" :> "prefs" :> Get '[JSON] Notifications.NotificationPref
                :<|> "notifications" :> "prefs" :> ReqBody '[JSON] Notifications.NotificationPrefInput :> Put '[JSON] Notifications.NotificationPref
                :<|> "notifications" :> "test" :> Post '[JSON] ()
                :<|> "notifications" :> "digest" :> Capture "frequency" Text :> Post '[JSON] ()
                -- Push notifications
                :<|> "notifications" :> "push" :> "subscribe" :> Header "Authorization" Text :> ReqBody '[JSON] Push.PushSubscriptionRequest :> Post '[JSON] ()
                :<|> "notifications" :> "push" :> "unsubscribe" :> Header "Authorization" Text :> Post '[JSON] ()
                -- Reports
                :<|> "reports" :> "pnl" :> Get '[JSON] Reports.Report
                :<|> "reports" :> "inventory" :> Get '[JSON] Reports.Report
                :<|> "reports" :> "export" :> ReqBody '[JSON] Reports.ReportExportRequest :> Post '[JSON] Reports.ReportExportResponse
                -- Stock
                :<|> "stock" :> Get '[JSON] [DAL.Stock]
                :<|> "stock" :> "movements" :> Get '[JSON] [DAL.StockMovement]
                :<|> "stock" :> "movements" :> ReqBody '[JSON] DAL.StockMovementInput :> Post '[JSON] DAL.MutationResult
                :<|> "stock" :> "movements" :> "goods" :> Capture "goodsId" Int64 :> Get '[JSON] [DAL.StockMovement]
                :<|> "stock" :> "summary" :> Get '[JSON] StockAPI.StockSummary
                :<|> "stock" :> "valuation" :> Get '[JSON] [StockAPI.StockValuationRow]
                :<|> "goods" :> "low-stock" :> Get '[JSON] [StockAPI.LowStockAlert]
                -- Lots
                :<|> "lots" :> Get '[JSON] [DAL.Lot]
                :<|> "lots" :> Capture "id" Int64 :> Get '[JSON] DAL.Lot
                :<|> "lots" :> "goods" :> Capture "goodsId" Int64 :> Get '[JSON] [DAL.Lot]
                :<|> "lots" :> "location" :> Capture "locationId" Int64 :> Get '[JSON] [DAL.Lot]
                -- Tenants
                :<|> "tenants" :> Get '[JSON] [DAL.Tenant]
                :<|> "tenants" :> Capture "id" Int64 :> Get '[JSON] DAL.Tenant
                :<|> "tenants" :> ReqBody '[JSON] DAL.TenantInput :> Post '[JSON] DAL.MutationResult
                -- Locations
                :<|> "locations" :> Get '[JSON] [DAL.Location]
                -- Orders
                :<|> "orders" :> Get '[JSON] [Orders.Order]
                :<|> "orders" :> ReqBody '[JSON] Orders.OrderInput :> Post '[JSON] Orders.Order
                :<|> "orders" :> Capture "id" Text :> Get '[JSON] Orders.Order
                :<|> "orders" :> Capture "id" Text :> ReqBody '[JSON] Orders.OrderInput :> Put '[JSON] Orders.Order
                :<|> "orders" :> Capture "id" Text :> "delete" :> Post '[JSON] ()
                -- Users
                :<|> "users" :> Get '[JSON] [User]
                :<|> "users" :> ReqBody '[JSON] UserInput :> Post '[JSON] DAL.MutationResult
                :<|> "users" :> Capture "id" Int64 :> Get '[JSON] User
                :<|> "users" :> Capture "id" Int64 :> ReqBody '[JSON] UserInput :> Put '[JSON] DAL.MutationResult
                :<|> "users" :> Capture "id" Int64 :> Delete '[JSON] DAL.MutationResult
                :<|> "audit-log" :> QueryParam "userId" Int64 :> QueryParam "action" Text :> QueryParam "resourceType" Text :> QueryParam "limit" Int :> Get '[JSON] [AuditLogEntry]
                :<|> "roles" :> Get '[JSON] [RoleEntry]
                :<|> "roles" :> Capture "rid" Int64 :> Get '[JSON] RoleEntry
                :<|> "roles" :> ReqBody '[JSON] RoleInput :> Post '[JSON] DAL.MutationResult
                :<|> "roles" :> Capture "rid" Int64 :> ReqBody '[JSON] RoleInput :> Put '[JSON] DAL.MutationResult
                :<|> "roles" :> Capture "rid" Int64 :> Delete '[JSON] DAL.MutationResult
                :<|> "permissions" :> Get '[JSON] [PermissionEntry]
                -- Integrations
                :<|> "integrations" :> Get '[JSON] [Integrations.Integration]
                :<|> "integrations" :> Capture "id" Int64 :> Get '[JSON] Integrations.Integration
                :<|> "integrations" :> Capture "id" Int64 :> "status" :> ReqBody '[JSON] Integrations.IntegrationStatus :> Put '[JSON] ()
                -- Workflows
                :<|> "workflows" :> Get '[JSON] [Workflow.Workflow]
                :<|> "workflows" :> ReqBody '[JSON] Workflow.WorkflowInput :> Post '[JSON] Workflow.Workflow
                :<|> "workflows" :> "instances" :> Get '[JSON] [Workflow.WorkflowInstance]
                :<|> "workflows" :> "instances" :> Capture "id" Text :> Get '[JSON] Workflow.WorkflowInstance
                :<|> "workflows" :> "instances" :> Capture "id" Text :> "complete" :> Post '[JSON] ()
                -- Classifiers
                :<|> "classifiers" :> "oksm" :> Get '[JSON] [DAL.OksmRecord]
                :<|> "classifiers" :> "okv" :> Get '[JSON] [DAL.OkvRecord]
                :<|> "classifiers" :> "okei" :> Get '[JSON] [DAL.OkeiRecord]
                :<|> "classifiers" :> "okpd2" :> Get '[JSON] [DAL.Okpd2Record]
                :<|> "classifiers" :> "okved2" :> Get '[JSON] [DAL.Okved2Record]
                :<|> "classifiers" :> "tnved" :> Get '[JSON] [DAL.TnvedRecord]
                :<|> "classifiers" :> "okato" :> Get '[JSON] [DAL.OkatoRecord]
                :<|> "classifiers" :> "oktmo" :> Get '[JSON] [DAL.OktmoRecord]
                :<|> "classifiers" :> "okof" :> Get '[JSON] [DAL.OkofRecord]
                :<|> "classifiers" :> "okp" :> Get '[JSON] [DAL.OkpRecord]
                :<|> "classifiers" :> "okdp" :> Get '[JSON] [DAL.OkdpRecord]
                :<|> "classifiers" :> "okso" :> Get '[JSON] [DAL.OksoRecord]
                :<|> "classifiers" :> "okun" :> Get '[JSON] [DAL.OkunRecord]
                :<|> "classifiers" :> "okud" :> Get '[JSON] [DAL.OkudRecord]
                :<|> "classifiers" :> "okfs" :> Get '[JSON] [DAL.OkfsRecord]
                :<|> "classifiers" :> "oknpo" :> Get '[JSON] [DAL.OknpoRecord]
                -- Balance sheet
                -- Payroll
                :<|> "payroll" :> "employees" :> Get '[JSON] [DAL.Employee]
                :<|> "payroll" :> "employees" :> Capture "id" Int64 :> Get '[JSON] DAL.Employee
                :<|> "payroll" :> "employees" :> ReqBody '[JSON] DAL.EmployeeInput :> Post '[JSON] DAL.MutationResult
                :<|> "payroll" :> "salaries" :> Get '[JSON] [DAL.Salary]
                :<|> "payroll" :> "salaries" :> Capture "empId" Int64 :> Get '[JSON] [DAL.Salary]
                :<|> "payroll" :> "salaries" :> ReqBody '[JSON] DAL.SalaryInput :> Post '[JSON] DAL.MutationResult
                :<|> "payroll" :> "employees" :> Capture "eid" Int64 :> ReqBody '[JSON] DAL.EmployeeInput :> Put '[JSON] DAL.MutationResult
                :<|> "payroll" :> "employees" :> Capture "eid" Int64 :> Delete '[JSON] DAL.MutationResult
                :<|> "payroll" :> "salaries" :> Capture "sid" Int64 :> Delete '[JSON] DAL.MutationResult
                :<|> "payroll" :> "calculate" :> ReqBody '[JSON] PayrollCalcRequest :> Post '[JSON] PR.PayrollResult
                :<|> "payroll" :> "calculate-and-save" :> ReqBody '[JSON] PayrollCalcRequest :> Post '[JSON] DAL.PayrollResult
                :<|> "payroll" :> "results" :> Get '[JSON] [DAL.PayrollResult]
                :<|> "payroll" :> "results" :> Capture "employeeId" Int64 :> Get '[JSON] [DAL.PayrollResult]
                :<|> "timesheets" :> Get '[JSON] [DAL.Timesheet]
                :<|> "timesheets" :> ReqBody '[JSON] DAL.TimesheetInput :> Post '[JSON] DAL.MutationResult
                :<|> "timesheets" :> Capture "tsid" Int64 :> ReqBody '[JSON] DAL.TimesheetInput :> Put '[JSON] DAL.MutationResult
                :<|> "timesheets" :> Capture "tsid" Int64 :> Delete '[JSON] DAL.MutationResult
                -- Balance sheet
                :<|> "balance" :> QueryParam "startDate" Day :> QueryParam "endDate" Day :> Get '[JSON] Accounting.BalanceResponse
                -- Accounting entries
                :<|> "accounting" :> "entries" :> QueryParam "startDate" Day :> QueryParam "endDate" Day :> QueryParam "accountId" Int64 :> Get '[JSON] [Accounting.JournalEntry]
                :<|> "accounting" :> "entries" :> ReqBody '[JSON] DAL.AccTurnInput :> Post '[JSON] DAL.MutationResult
                :<|> "accounting" :> "balance-history" :> QueryParam "accountId" Int64 :> QueryParam "startDate" Day :> QueryParam "endDate" Day :> QueryParam "interval" Text :> Get '[JSON] [Accounting.BalanceHistoryEntry]
                -- Backup
                :<|> "backup" :> Get '[JSON] Text
           )

-- ── Server ───────────────────────────────────────────────────────────────────

server :: Env -> Server SurypusApi
server env =
    handleLogin env
        :<|> handleRegister env
        :<|> handleAuthMe env
        :<|> graphQLServer env
        :<|> billsList env
        :<|> billsCreate env
        :<|> billGet env
        :<|> billPost env
        :<|> billStatusUpdate env
        :<|> billDelete env
        :<|> billTemplatesList env
        :<|> billTemplateCreate env
        :<|> billTemplateDelete env
        :<|> goodsList env
        :<|> personsList env
        :<|> paymentsList env
        :<|> paymentsCreate env
        :<|> paymentsGet env
        :<|> paymentsUpdate env
        :<|> paymentsDelete env
        :<|> paymentsAging env
        :<|> dashboardKPI env
        :<|> dashboardRevenue env
        :<|> dashboardOrders env
        :<|> dashboardStock env
        :<|> crmDealsList env
        :<|> crmDealCreate env
        :<|> crmDealGet env
        :<|> crmDealStageUpdate env
        :<|> crmPipelineForecast env
        :<|> crmDealActivities env
        :<|> crmContactsList env
        :<|> crmContactCreate env
        :<|> crmContactGet env
        :<|> crmContactUpdate env
        :<|> crmContactDelete env
        :<|> crmContactSearch env
        :<|> crmCompaniesList env
        :<|> crmCompanyCreate env
        :<|> crmCompanyGet env
        :<|> crmCompanyUpdate env
        :<|> crmCompanyDelete env
        :<|> crmCompanySearch env
        :<|> crmPipelineStagesList env
        :<|> crmPipelineStageRules env
        :<|> crmPipelineForecastRefresh env
        :<|> crmDealStageHistory env
        :<|> notificationsList env
        :<|> notificationsCreate env
        :<|> notificationsMarkRead env
        :<|> notificationsGetPrefs env
        :<|> notificationsUpdatePrefs env
        :<|> notificationsSendTest env
        :<|> notificationsSendDigest env
        :<|> pushSubscribe env
        :<|> pushUnsubscribe env
        :<|> reportsPnL env
        :<|> reportsInventory env
        :<|> reportsExport env
        :<|> stockList env
        :<|> stockMovementsList env
        :<|> stockMovementCreate env
        :<|> stockMovementsByGoods env
        :<|> stockSummary env
        :<|> stockValuation env
        :<|> goodsLowStock env
        :<|> lotsList env
        :<|> lotGet env
        :<|> lotsByGoods env
        :<|> lotsByLocation env
        :<|> tenantsList env
        :<|> tenantGet env
        :<|> tenantCreate env
        :<|> locationsList env
        :<|> ordersList env
        :<|> ordersCreate env
        :<|> ordersGet env
        :<|> ordersUpdate env
        :<|> ordersDelete env
        :<|> usersList env
        :<|> usersCreate env
        :<|> usersGet env
        :<|> usersUpdate env
        :<|> usersDelete env
        :<|> auditLogList env
        :<|> rolesList env
        :<|> roleGet env
        :<|> roleCreate env
        :<|> roleUpdate env
        :<|> roleDelete env
        :<|> permissionsList env
        :<|> integrationsList env
        :<|> integrationGet env
        :<|> integrationUpdateStatus env
        :<|> workflowsList env
        :<|> workflowsCreate env
        :<|> workflowsInstancesList env
        :<|> workflowsGetInstance env
        :<|> workflowsCompleteInstance env
        :<|> classifiersOksmList env
        :<|> classifiersOkvList env
        :<|> classifiersOkeiList env
        :<|> classifiersOkpd2List env
        :<|> classifiersOkved2List env
        :<|> classifiersTnvedList env
        :<|> classifiersOkatoList env
        :<|> classifiersOktmoList env
        :<|> classifiersOkofList env
        :<|> classifiersOkpList env
        :<|> classifiersOkdpList env
        :<|> classifiersOksoList env
        :<|> classifiersOkunList env
        :<|> classifiersOkudList env
        :<|> classifiersOkfsList env
        :<|> classifiersOknpoList env
        :<|> payrollEmployeesList env
        :<|> payrollEmployeeGet env
        :<|> payrollEmployeeCreate env
        :<|> payrollSalariesList env
        :<|> payrollSalaryByEmployee env
        :<|> payrollSalaryCreate env
        :<|> payrollEmployeeUpdate env
        :<|> payrollEmployeeDelete env
        :<|> payrollSalaryDelete env
        :<|> payrollCalculate env
        :<|> payrollCalculateAndSave env
        :<|> payrollResultsList env
        :<|> payrollResultsByEmployee env
        :<|> timesheetsList env
        :<|> timesheetsCreate env
        :<|> timesheetsUpdate env
        :<|> timesheetsDelete env
        :<|> handleBalance env
        :<|> handleJournalEntries env
        :<|> handleCreateEntry env
        :<|> handleBalanceHistory env
        :<|> backupHandler env

-- ── Helpers ──────────────────────────────────────────────────────────────────

ok :: QueryResult a -> (a -> Handler b) -> Handler b
ok (QuerySuccess a) f = f a
ok (QueryError "Not Found") _ = throwError err404
ok (QueryError e) _ = throwError $ err500{errBody = LBS.encodeUtf8 (TL.fromStrict e)}

liftQ :: IO (QueryResult a) -> Handler a
liftQ action = liftIO action >>= \r -> ok r pure

-- ── Handlers ─────────────────────────────────────────────────────────────────

hashPassword :: Text -> Text
hashPassword pwd = DT.pack $ show $ hash @ByteString @SHA256 (TE.encodeUtf8 pwd)

handleLogin :: Env -> LoginRequest -> Handler LoginResponse
handleLogin env req = do
    result <- liftIO $ DAL.Mutations.authenticateUser (envConnectionPool env) (lrUsername req) (lrPassword req)
    case result of
        QueryError e -> throwError $ err500{errBody = LBS.encodeUtf8 (TL.fromStrict e)}
        QuerySuccess Nothing -> throwError err401
        QuerySuccess (Just user) -> do
            token <- liftIO $ JWT.generateToken (envConnectionPool env) user
            pure $ LoginResponse token Nothing (DAL.userId user) 3600

handleRegister :: Env -> RegisterRequest -> Handler LoginResponse
handleRegister env req = do
    let pwdHash = hashPassword (rrPassword req)
        input = DAL.UserInput (rrUsername req) pwdHash Nothing 1
    result <- liftIO $ DAL.Mutations.createUser (envConnectionPool env) input
    case result of
        QueryError e -> throwError $ err500{errBody = LBS.encodeUtf8 (TL.fromStrict e)}
        QuerySuccess mr -> case DAL.mrId mr of
            Just uid -> do
                let user = DAL.User uid (rrUsername req) (Just pwdHash) (rrEmail req) Nothing 1 0
                token <- liftIO $ JWT.generateToken (envConnectionPool env) user
                pure $ LoginResponse token Nothing uid 3600
            Nothing -> throwError $ err500{errBody = "Failed to create user"}

handleAuthMe :: Env -> Maybe Text -> Handler UserInfoResponse
handleAuthMe env mbAuth = do
    case mbAuth >>= DT.stripPrefix "Bearer " of
        Nothing -> throwError err401
        Just token -> do
            result <- liftIO $ JWT.verifyToken token
            case result of
                Left _ -> throwError err401
                Right claims -> do
                    let uid = JWT.ucUserId claims
                        uname = JWT.ucUsername claims
                    pure $ UserInfoResponse uid uname Nothing

billsList env = liftQ $ Bills.listBills (envConnectionPool env)
billsCreate env input = do
    result <- liftIO $ Bills.createBill (envConnectionPool env) input
    case result of
        QuerySuccess mr -> case mrId mr of
            Just bid -> liftQ $ Bills.getBill (envConnectionPool env) bid
            Nothing -> liftQ $ return $ QueryError "Bill created but no ID returned"
        QueryError err -> liftQ $ return $ QueryError err
billGet env bid = liftQ $ Bills.getBill (envConnectionPool env) bid
billPost env bid = liftQ $ Bills.postBill (envConnectionPool env) bid
billStatusUpdate env bid mstatus = case mstatus of
    Just s -> liftQ $ Bills.updateBillStatus (envConnectionPool env) bid s
    Nothing -> liftQ $ return $ QueryError "status query parameter required"
billDelete env bid = liftQ $ Bills.deleteBill (envConnectionPool env) bid
billTemplatesList env = liftQ $ BillTemplates.listTemplates (envConnectionPool env)
billTemplateCreate env mname mcontent = case (mname, mcontent) of
    (Just n, Just c) -> liftQ $ BillTemplates.saveTemplate (envConnectionPool env) n c
    _ -> liftQ $ return $ QueryError "name and content query parameters required"
billTemplateDelete env tid = liftQ $ BillTemplates.deleteTemplate (envConnectionPool env) tid

goodsList env = liftQ $ Goods.listGoods (envConnectionPool env)
personsList env = liftQ $ Persons.listPersons (envConnectionPool env) Nothing Nothing Nothing Nothing Nothing
paymentsList env = liftQ $ Payments.listPayments (envConnectionPool env)
paymentsCreate env i = liftQ $ Payments.createPayment (envConnectionPool env) i
paymentsGet env pid = liftQ $ Payments.getPayment (envConnectionPool env) pid
paymentsUpdate env pid i = liftQ $ Payments.updatePayment (envConnectionPool env) pid i
paymentsDelete env pid = liftQ $ Payments.deletePayment (envConnectionPool env) pid
paymentsAging env = liftQ $ Payments.getAgingReport (envConnectionPool env)

dashboardKPI env = liftQ $ Dashboard.getDashboardKPI (envConnectionPool env)
dashboardRevenue env = liftQ $ Dashboard.getRevenueTrend (envConnectionPool env)
dashboardOrders env = liftQ $ Dashboard.getOrderStatuses (envConnectionPool env)
dashboardStock env = liftQ $ fmap (\s -> [s]) <$> Dashboard.getStockSummary (envConnectionPool env)

crmDealsList env = liftQ $ CRM.listDeals (envConnectionPool env)
crmDealCreate env i = liftQ $ CRM.createDeal (envConnectionPool env) i
crmDealGet env did = liftQ $ CRM.getDeal (envConnectionPool env) did
crmDealStageUpdate env d s = liftQ $ CRM.updateDealStage (envConnectionPool env) d s
crmPipelineForecast env = liftQ $ CRM.getPipelineForecast (envConnectionPool env)
crmDealActivities env did = liftQ $ CRM.listActivities (envConnectionPool env) did
crmContactsList env = liftQ $ CRM.listContacts (envConnectionPool env)
crmContactCreate env i = liftQ $ CRM.createContact (envConnectionPool env) i
crmContactGet env cid = liftQ $ CRM.getContact (envConnectionPool env) cid
crmContactUpdate env cid i = liftQ $ CRM.updateContact (envConnectionPool env) cid i
crmContactDelete env cid = liftQ $ CRM.deleteContact (envConnectionPool env) cid
crmContactSearch env q = liftQ $ CRM.searchContacts (envConnectionPool env) q
crmCompaniesList env = liftQ $ CRM.listCompanies (envConnectionPool env)
crmCompanyCreate env i = liftQ $ CRM.createCompany (envConnectionPool env) i
crmCompanyGet env coid = liftQ $ CRM.getCompany (envConnectionPool env) coid
crmCompanyUpdate env coid i = liftQ $ CRM.updateCompany (envConnectionPool env) coid i
crmCompanyDelete env coid = liftQ $ CRM.deleteCompany (envConnectionPool env) coid
crmCompanySearch env q = liftQ $ CRM.searchCompanies (envConnectionPool env) q
crmPipelineStagesList env = liftQ $ CRM.listPipelineStages (envConnectionPool env)
crmPipelineStageRules env s = liftQ $ CRM.getStageRules (envConnectionPool env) s
crmPipelineForecastRefresh env = liftQ $ CRM.refreshPipelineForecast (envConnectionPool env)
crmDealStageHistory env did = liftQ $ CRM.getStageHistory (envConnectionPool env) did

notificationsList env = liftQ $ Notifications.listNotifications (envConnectionPool env) 1
notificationsCreate env i = liftQ $ Notifications.createNotification (envConnectionPool env) i
notificationsMarkRead env nid = liftQ $ Notifications.markNotificationRead (envConnectionPool env) nid
notificationsGetPrefs env = liftQ $ Notifications.getNotificationPrefs (envConnectionPool env) 1
notificationsUpdatePrefs env i = liftQ $ Notifications.updateNotificationPrefs (envConnectionPool env) 1 i
notificationsSendTest env = liftQ $ Notifications.sendTestNotification (envConnectionPool env)
notificationsSendDigest env f = liftQ $ Notifications.sendDigestNotification (envConnectionPool env) 1 f

reportsPnL env = liftQ $ Reports.getPnLReport (envConnectionPool env)
reportsInventory env = liftQ $ Reports.getInventoryReport (envConnectionPool env)

reportsExport :: Env -> Reports.ReportExportRequest -> Handler Reports.ReportExportResponse
reportsExport env req = do
    let rptType = Reports.rerReportType req
    result <- liftIO $ Reports.generateReportPdf (envConnectionPool env) rptType
    case result of
        Left err -> throwError $ err500{errBody = LBS.encodeUtf8 (TL.fromStrict err)}
        Right filename -> do
            let url = DT.concat ["/api/v1/reports/download/", filename]
            return $ Reports.ReportExportResponse url "ok"

stockList :: Env -> Handler [DAL.Stock]
stockList env = liftQ $ DAL.QueriesORM.getStockAll (envConnectionPool env)

stockMovementsList :: Env -> Handler [DAL.StockMovement]
stockMovementsList env = liftQ $ DAL.QueriesORM.getStockMovements (envConnectionPool env)

stockMovementCreate :: Env -> DAL.StockMovementInput -> Handler DAL.MutationResult
stockMovementCreate env input = liftQ $ DAL.Mutations.createStockMovement (envConnectionPool env) input

stockMovementsByGoods :: Env -> Int64 -> Handler [DAL.StockMovement]
stockMovementsByGoods env gid = liftQ $ DAL.QueriesORM.getStockMovementsByGoods (envConnectionPool env) gid

stockSummary :: Env -> Handler StockAPI.StockSummary
stockSummary env = liftQ $ StockAPI.getStockSummary (envConnectionPool env)

stockValuation :: Env -> Handler [StockAPI.StockValuationRow]
stockValuation env = liftQ $ StockAPI.getValuation (envConnectionPool env)

goodsLowStock :: Env -> Handler [StockAPI.LowStockAlert]
goodsLowStock env = liftQ $ StockAPI.getLowStock (envConnectionPool env)

lotsList :: Env -> Handler [DAL.Lot]
lotsList env = liftQ $ DAL.QueriesORM.getLots (envConnectionPool env)

lotGet :: Env -> Int64 -> Handler DAL.Lot
lotGet env lid = liftQ $ DAL.QueriesORM.getLotById (envConnectionPool env) lid

lotsByGoods :: Env -> Int64 -> Handler [DAL.Lot]
lotsByGoods env gid = liftQ $ DAL.QueriesORM.getLotsByGoods (envConnectionPool env) gid

lotsByLocation :: Env -> Int64 -> Handler [DAL.Lot]
lotsByLocation env lid = liftQ $ DAL.QueriesORM.getLotsByLocation (envConnectionPool env) lid

tenantsList :: Env -> Handler [DAL.Tenant]
tenantsList env = liftQ $ DAL.QueriesORM.getTenants (envConnectionPool env)

tenantGet :: Env -> Int64 -> Handler DAL.Tenant
tenantGet env tid = liftQ $ DAL.QueriesORM.getTenantById (envConnectionPool env) tid

tenantCreate :: Env -> DAL.TenantInput -> Handler DAL.MutationResult
tenantCreate env input = liftIO $ do
    result <- runSqlPool
        (rawSql "INSERT INTO tenants (name, slug, schema_name, is_active) VALUES (?, ?, 'public', true) RETURNING id"
            [PersistText (DAL.tiTenantName input), PersistText (DAL.tiSlug input)])
        (envConnectionPool env)
    case result of
        [Single (insertedId :: Int64)] -> return $ DAL.MutationResult True (Just insertedId) "Tenant created"
        _ -> return $ DAL.MutationResult False Nothing "Failed to create tenant"

locationsList :: Env -> Handler [DAL.Location]
locationsList env = liftQ $ DAL.QueriesORM.getLocations (envConnectionPool env)

ordersList env = liftQ $ Orders.listOrders (envConnectionPool env)
ordersCreate env i = liftQ $ Orders.createOrder (envConnectionPool env) i
ordersGet env oid = liftQ $ Orders.getOrder (envConnectionPool env) oid
ordersUpdate env oid i = liftQ $ Orders.updateOrder (envConnectionPool env) oid i
ordersDelete env oid = liftQ $ Orders.deleteOrder (envConnectionPool env) oid

integrationsList env = liftQ $ Integrations.listIntegrations (envConnectionPool env)
integrationGet env iid = liftQ $ Integrations.getIntegration (envConnectionPool env) iid
integrationUpdateStatus env iid status = liftQ $ Integrations.updateIntegrationStatus (envConnectionPool env) iid status

usersList env = liftQ $ DAL.Mutations.listUsers (envConnectionPool env)
usersCreate env i = liftQ $ DAL.Mutations.createUser (envConnectionPool env) i
usersGet env uid = liftQ $ DAL.Mutations.getUser (envConnectionPool env) uid
usersUpdate env uid i = liftQ $ DAL.Mutations.updateUser (envConnectionPool env) uid i
usersDelete env uid = liftQ $ DAL.Mutations.deleteUser (envConnectionPool env) uid

auditLogList :: Env -> Maybe Int64 -> Maybe Text -> Maybe Text -> Maybe Int -> Handler [AuditLogEntry]
auditLogList env mUserId mAction mResourceType mLimit = do
  let sql = "SELECT id, user_id, action, resource_type, resource_id, old_values, new_values, ip_address, CAST(created_at AS TEXT) FROM audit_log ORDER BY created_at DESC LIMIT ?"
      limit = fromMaybe 100 mLimit
  rows <- liftIO $ runSqlPool (rawSql sql [PersistInt64 (fromIntegral limit)]) (envConnectionPool env)
  let entries = map (\(Single i, Single u, Single a, Single rt, Single ri, Single ov, Single nv, Single ip, Single ca) ->
        AuditLogEntry i u a rt ri ov nv ip ca) rows
  pure entries

rolesList :: Env -> Handler [RoleEntry]
rolesList env = do
  rows <- liftIO $ runSqlPool (rawSql "SELECT id, name FROM role ORDER BY name" []) (envConnectionPool env)
  pure $ map (\(Single i, Single n) -> RoleEntry i n) rows

roleGet :: Env -> Int64 -> Handler RoleEntry
roleGet env rid = do
  rows <- liftIO $ runSqlPool (rawSql "SELECT id, name FROM role WHERE id = ?" [PersistInt64 rid]) (envConnectionPool env)
  case rows of
    [(Single i, Single n)] -> pure $ RoleEntry i n
    _ -> throwError err404

roleCreate :: Env -> RoleInput -> Handler DAL.MutationResult
roleCreate env input = do
  rows <- liftIO $ runSqlPool (rawSql "INSERT INTO role (name) VALUES (?) RETURNING id" [PersistText (riName input)]) (envConnectionPool env)
  case rows of
    [Single (i :: Int64)] -> pure $ DAL.MutationResult True (Just i) "Role created"
    _ -> pure $ DAL.MutationResult True Nothing "Role created"

roleUpdate :: Env -> Int64 -> RoleInput -> Handler DAL.MutationResult
roleUpdate env rid input = do
  (_ :: [Single Int64]) <- liftIO $ runSqlPool (rawSql "UPDATE role SET name = ? WHERE id = ?" [PersistText (riName input), PersistInt64 rid]) (envConnectionPool env)
  pure $ DAL.MutationResult True (Just rid) "Role updated"

roleDelete :: Env -> Int64 -> Handler DAL.MutationResult
roleDelete env rid = do
  (_ :: [Single Int64]) <- liftIO $ runSqlPool (rawSql "DELETE FROM role WHERE id = ?" [PersistInt64 rid]) (envConnectionPool env)
  pure $ DAL.MutationResult True (Just rid) "Role deleted"

permissionsList :: Env -> Handler [PermissionEntry]
permissionsList env = do
  rows <- liftIO $ runSqlPool (rawSql "SELECT id, name FROM permission ORDER BY name" []) (envConnectionPool env)
  pure $ map (\(Single i, Single n) -> PermissionEntry i n) rows

workflowsList env = liftQ $ Workflow.listWorkflows (envConnectionPool env)
workflowsCreate env i = liftQ $ Workflow.createWorkflow (envConnectionPool env) i
workflowsInstancesList env = liftQ $ Workflow.listWorkflowInstances (envConnectionPool env)
workflowsGetInstance env iid = liftQ $ Workflow.getWorkflowInstance (envConnectionPool env) iid
workflowsCompleteInstance env iid = liftQ $ Workflow.completeWorkflow (envConnectionPool env) iid

-- ── Classifier handlers ──────────────────────────────────────────────────────
classifiersOksmList env = liftQ $ Classifiers.listOksm (envConnectionPool env)
classifiersOkvList env = liftQ $ Classifiers.listOkv (envConnectionPool env)
classifiersOkeiList env = liftQ $ Classifiers.listOkei (envConnectionPool env)
classifiersOkpd2List env = liftQ $ Classifiers.listOkpd2 (envConnectionPool env)
classifiersOkved2List env = liftQ $ Classifiers.listOkved2 (envConnectionPool env)
classifiersTnvedList env = liftQ $ Classifiers.listTnved (envConnectionPool env)
classifiersOkatoList env = liftQ $ Classifiers.listOkato (envConnectionPool env)
classifiersOktmoList env = liftQ $ Classifiers.listOktmo (envConnectionPool env)
classifiersOkofList env = liftQ $ Classifiers.listOkof (envConnectionPool env)
classifiersOkpList env = liftQ $ Classifiers.listOkp (envConnectionPool env)
classifiersOkdpList env = liftQ $ Classifiers.listOkdp (envConnectionPool env)
classifiersOksoList env = liftQ $ Classifiers.listOkso (envConnectionPool env)
classifiersOkunList env = liftQ $ Classifiers.listOkun (envConnectionPool env)
classifiersOkudList env = liftQ $ Classifiers.listOkud (envConnectionPool env)
classifiersOkfsList env = liftQ $ Classifiers.listOkfs (envConnectionPool env)
classifiersOknpoList env = liftQ $ Classifiers.listOknpo (envConnectionPool env)

-- ── Payroll handlers ───────────────────────────────────────────────────────
payrollEmployeesList env = liftQ $ Payroll.getEmployees (envConnectionPool env)
payrollEmployeeGet env eid = liftQ $ Payroll.getEmployeeById (envConnectionPool env) eid
payrollSalariesList env = liftQ $ Payroll.getSalaries (envConnectionPool env)
payrollSalaryByEmployee env eid = liftQ $ Payroll.getSalaryByEmployee (envConnectionPool env) eid
payrollEmployeeCreate env input = liftQ $ Payroll.createEmployee (envConnectionPool env) input
payrollSalaryCreate env input = liftQ $ Payroll.createSalary (envConnectionPool env) input
payrollEmployeeUpdate env eid input = liftQ $ Payroll.updateEmployee (envConnectionPool env) eid input
payrollEmployeeDelete env eid = liftQ $ Payroll.deleteEmployee (envConnectionPool env) eid
payrollSalaryDelete env sid = liftQ $ Payroll.deleteSalary (envConnectionPool env) sid

payrollCalculate :: Env -> PayrollCalcRequest -> Handler PR.PayrollResult
payrollCalculate env req =
    let prReq = PR.PayrollRequest
          { PR.prEmployeeId = pcrEmployeeId req
          , PR.prTenantId = pcrTenantId req
          , PR.prPeriod = pcrPeriod req
          , PR.prBaseSalary = fromRational (toRational (pcrBaseSalary req))
          , PR.prBonus = fromRational (toRational (pcrBonus req))
          , PR.prDaysWorked = pcrDaysWorked req
          , PR.prVacationDays = pcrVacationDays req
          , PR.prSickDays = pcrSickDays req
          }
    in pure $ PR.calculatePayroll prReq

payrollCalculateAndSave :: Env -> PayrollCalcRequest -> Handler DAL.PayrollResult
payrollCalculateAndSave env req = do
  let prReq = PR.PayrollRequest
        { PR.prEmployeeId = pcrEmployeeId req
        , PR.prTenantId = pcrTenantId req
        , PR.prPeriod = pcrPeriod req
        , PR.prBaseSalary = fromRational (toRational (pcrBaseSalary req))
        , PR.prBonus = fromRational (toRational (pcrBonus req))
        , PR.prDaysWorked = pcrDaysWorked req
        , PR.prVacationDays = pcrVacationDays req
        , PR.prSickDays = pcrSickDays req
        }
  liftQ $ PR.calculateAndSavePayroll (envConnectionPool env) prReq (pcrUserId req)

payrollResultsList env = liftQ $ Payroll.getPayrollResults (envConnectionPool env)
payrollResultsByEmployee env eid = liftQ $ Payroll.getPayrollResultsByEmployee (envConnectionPool env) eid

timesheetsList env = liftQ $ Payroll.getTimesheets (envConnectionPool env)
timesheetsCreate env input = liftQ $ Payroll.createTimesheet (envConnectionPool env) input
timesheetsUpdate env tsid input = liftQ $ Payroll.updateTimesheet (envConnectionPool env) tsid input
timesheetsDelete env tsid = liftQ $ Payroll.deleteTimesheet (envConnectionPool env) tsid

-- ── Accounting handlers ─────────────────────────────────────────────────────
handleBalance :: Env -> Maybe Day -> Maybe Day -> Handler Accounting.BalanceResponse
handleBalance env s e = liftQ $ Accounting.getBalance (envConnectionPool env) s e

handleJournalEntries :: Env -> Maybe Day -> Maybe Day -> Maybe Int64 -> Handler [Accounting.JournalEntry]
handleJournalEntries env s e a = liftQ $ Accounting.getJournalEntries (envConnectionPool env) s e a

handleCreateEntry :: Env -> DAL.AccTurnInput -> Handler DAL.MutationResult
handleCreateEntry env input = liftQ $ DAL.Mutations.createAccTurn (envConnectionPool env) input

handleBalanceHistory :: Env -> Maybe Int64 -> Maybe Day -> Maybe Day -> Maybe Text -> Handler [Accounting.BalanceHistoryEntry]
handleBalanceHistory env mAccountId mStart mEnd mInterval =
    case mAccountId of
        Nothing -> throwError err400 { errBody = "accountId is required" }
        Just accountId -> do
            let startDate = fromMaybe (fromGregorian 2000 1 1) mStart
                endDate = fromMaybe (fromGregorian 2099 12 31) mEnd
                interval = fromMaybe "month" mInterval
            liftQ $ Accounting.getBalanceHistory (envConnectionPool env) accountId startDate endDate interval

-- Push notification handlers
pushSubscribe :: Env -> Maybe Text -> Push.PushSubscriptionRequest -> Handler ()
pushSubscribe env mbAuth req = do
    uid <- extractUserId mbAuth
    liftIO $ Push.subscribe (envPushStore env) uid req

pushUnsubscribe :: Env -> Maybe Text -> Handler ()
pushUnsubscribe env mbAuth = do
    uid <- extractUserId mbAuth
    liftIO $ Push.unsubscribe (envPushStore env) uid

extractUserId :: Maybe Text -> Handler Int64
extractUserId mbAuth = do
    token <- case mbAuth >>= DT.stripPrefix "Bearer " of
        Nothing -> throwError err401
        Just t -> pure t
    result <- liftIO $ JWT.verifyToken token
    case result of
        Left _ -> throwError err401
        Right claims -> pure (JWT.ucUserId claims)

graphQLServer :: Env -> Server GraphQL.GraphQLAPI
graphQLServer env = GraphQL.graphqlHandler (envConnectionPool env)

backupHandler :: Env -> Handler Text
backupHandler env = do
    result <- liftIO $ readProcess "pg_dump" ["--dbname=postgresql://localhost:5432/surupus"] ""
    pure $ TL.toStrict $ TL.pack $ take 1000 result
