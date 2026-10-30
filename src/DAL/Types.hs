-- Ledger entry: single canonical type for double-entry bookkeeping (Phase 3).
-- Originally: DAL.Types - Phase 1 stubs (Person, Goods, Payment, User, etc.)
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
module DAL.Types
  ( -- * Ledger entry (Phase 3)
    LedgerEntry (..)
  , PersonEntity (..)
  , CustomerEntity (..)
  , ProductionOrderEntity (..)
  , ReportConfigEntity (..)
  , BillEntity (..)
  , TaxEntity (..)
  , EntryId
  , -- * Phase 1 stubs
    Pagination (..)
  , QueryResult (..)
  , CommandResult (..)
  , MutationResult (..)
  , Person (..)
  , Goods (..)
  , Bill (..)
  , Location (..)
  , Order (..)
  , Payment (..)
  , User (..)
  , Price (..)
  , GoodsPrice (..)
  , Tax (..)
  , Currency (..)
  , AccPlan (..)
  , AccTurn (..)
  , AccTurnInput (..)
  , Employee (..)
  , Salary (..)
  , StockMovement (..)
  , Timesheet (..)
  , BillLine (..)
  , PayrollResult (..)
  , DocumentRegisterType (..)
  , Workflow (..)
  , WorkflowInput (..)
  , WorkflowInstance (..)
  , WorkflowStatus (..)
  , OksmRecord (..)
  , OkvRecord (..)
  , OkeiRecord (..)
  , Okpd2Record (..)
  , Okved2Record (..)
  , TnvedRecord (..)
  , OkatoRecord (..)
  , OktmoRecord (..)
  , OkofRecord (..)
  , OkpRecord (..)
  , OkdpRecord (..)
  , OksoRecord (..)
  , OkunRecord (..)
  , OkudRecord (..)
  , OkfsRecord (..)
  , OknpoRecord (..)
  , Stock (..)
  , Lot (..)
  , Tenant (..)
  , TenantInput (..)
  , UserInput (..)
  , mrId
  , -- * Type aliases
    PaymentInput
  , BillInput
  , EmployeeInput
  , SalaryInput
  , StockMovementInput
  , TimesheetInput
  ) where

import Data.Decimal (Decimal)
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime)
import GHC.Generics (Generic)

-- | PersonEntity (DSL-generated entity)
data PersonEntity = PersonEntity
  { personEntityId :: !T.Text
  , code :: !T.Text
  , name :: !T.Text
  , inn :: !T.Text
  , kpp :: !T.Text
  , personType :: !T.Text
  , status :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON PersonEntity
instance ToJSON PersonEntity

-- | BillEntity (DSL-generated entity)
data BillEntity = BillEntity
  { billEntityId :: !T.Text
  , billEntityNumber :: !T.Text
  , billEntityCustomerId :: !T.Text
  , billEntityTotal :: !T.Text
  , billEntityStatus :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON BillEntity
instance ToJSON BillEntity

-- | TaxEntity (DSL-generated entity)
data TaxEntity = TaxEntity
  { taxEntityId :: !T.Text
  , taxEntityCode :: !T.Text
  , taxEntityName :: !T.Text
  , taxEntityRate :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON TaxEntity
instance ToJSON TaxEntity

type EntryId = Int

-- | Ledger entry: single canonical type for double-entry bookkeeping (Phase 3).
data LedgerEntry = LedgerEntry
  { leId     :: EntryId
  , leDebit  :: Text
  , leCredit :: Text
  , leAmount :: Decimal
  } deriving (Eq, Show)

-- | Pagination parameters (Phase 1: stub)
data Pagination = Pagination
  { paginationOffset :: !Int
  , paginationLimit  :: !Int
  } deriving (Show, Eq, Generic)

instance FromJSON Pagination
instance ToJSON Pagination

-- | Query result with multiple constructors
data QueryResult a
  = QuerySuccess !a
  | QueryError !T.Text
  | QueryResults ![a] !Int
  deriving (Show, Eq, Generic)

instance FromJSON a => FromJSON (QueryResult a)
instance ToJSON a => ToJSON (QueryResult a)

-- | Command result (success or error)
data CommandResult a
  = CommandSuccess !a
  | CommandError !T.Text
  deriving (Show, Eq, Generic)

instance FromJSON a => FromJSON (CommandResult a)
instance ToJSON a => ToJSON (CommandResult a)

-- | Mutation result (success/failure with optional ID and message)
data MutationResult = MutationResult
  { mutationSuccess :: !Bool
  , mutationId :: !(Maybe Int64)
  , mutationMessage :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON MutationResult
instance ToJSON MutationResult

-- | Person (Phase 1: stub)
data Person = Person
  { personId :: !Int
  , personCode :: !(Maybe T.Text)
  , personName :: !T.Text
  , personINN :: !(Maybe T.Text)
  , personKPP :: !(Maybe T.Text)
  , personType :: !(Maybe Int)
  , personStatus :: !(Maybe Int)
  } deriving (Show, Eq, Generic)

instance FromJSON Person
instance ToJSON Person

-- | Goods (Phase 1: stub)
data Goods = Goods
  { goodsId :: !Int
  , goodsCode :: !(Maybe T.Text)
  , goodsName :: !T.Text
  , goodsFullName :: !(Maybe T.Text)
  , goodsBarcode :: !(Maybe T.Text)
  , goodsUnitId :: !(Maybe Int)
  , goodsCategoryId :: !(Maybe Int)
  , goodsType :: !(Maybe T.Text)
  , goodsStatus :: !(Maybe T.Text)
  , goodsMinStock :: !(Maybe T.Text)
  , goodsMaxStock :: !(Maybe T.Text)
  , goodsWeight :: !(Maybe T.Text)
  , goodsVolume :: !(Maybe T.Text)
  , goodsCreatedAt :: !(Maybe T.Text)
  , goodsUpdatedAt :: !(Maybe T.Text)
  } deriving (Show, Eq, Generic)

instance FromJSON Goods
instance ToJSON Goods

-- | Bill (Phase 1: stub)
data Bill = Bill
  { billId :: !Int
  , billCode :: !(Maybe T.Text)
  , billType :: !(Maybe T.Text)
  , billStatus :: !(Maybe T.Text)
  , billDate :: !Day
  , billPersonId :: !(Maybe Int)
  , billLocationId :: !(Maybe Int)
  , billTotal :: !Double
  , billDiscount :: !Double
  , billTaxAmount :: !Double
  } deriving (Show, Eq, Generic)

instance FromJSON Bill
instance ToJSON Bill

-- | Location (Phase 1: stub)
data Location = Location
  { locationId :: !Int64
  , locationCode :: !Text
  , locationName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON Location
instance ToJSON Location

-- | Order (Phase 1: stub)
data Order = Order
  { orderId :: !Int64
  , orderCode :: !Text
  , orderName :: !Text
  , orderDate :: !UTCTime
  , orderPersonId :: !(Maybe Int64)
  , orderLocationId :: !(Maybe Int64)
  , orderType :: !(Maybe T.Text)
  , orderTotal :: !(Maybe Double)
  , orderDiscount :: !(Maybe Double)
  , orderTax :: !(Maybe Double)
  } deriving (Show, Eq, Generic)

instance FromJSON Order
instance ToJSON Order

-- | Payment (Phase 1: stub)
data Payment = Payment
  { paymentId :: !Int64
  , paymentBillId :: !Int64
  , paymentAmount :: !Double
  , paymentDate :: !UTCTime
  , paymentMethod :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON Payment
instance ToJSON Payment

-- | User (Phase 1: stub)
data User = User
  { userId :: !Int64
  , userName :: !Text
  , userPassword :: !(Maybe T.Text)
  , userEmail :: !(Maybe T.Text)
  , userPersonId :: !(Maybe Int64)
  , userStatus :: !Text
  , userTenantId :: !Int64
  } deriving (Show, Eq, Generic)

instance FromJSON User
instance ToJSON User

-- | Price (Phase 1: stub)
data Price = Price
  { priceId :: !Int64
  , priceGoodsId :: !Int64
  , priceType :: !(Maybe Text)
  , pricePrice :: !Double
  , priceMinPrice :: !(Maybe Double)
  , priceStartDate :: !(Maybe UTCTime)
  , priceEndDate :: !(Maybe UTCTime)
  } deriving (Show, Eq, Generic)

instance FromJSON Price
instance ToJSON Price

-- | GoodsPrice (Phase 1: stub)
data GoodsPrice = GoodsPrice
  { goodsPriceId :: !Int64
  , goodsPriceGoodsId :: !Int64
  , goodsPriceType :: !(Maybe Text)
  , goodsPricePrice :: !Double
  , goodsPriceMinPrice :: !(Maybe Double)
  , goodsPriceStartDate :: !(Maybe UTCTime)
  , goodsPriceEndDate :: !(Maybe UTCTime)
  } deriving (Show, Eq, Generic)

instance FromJSON GoodsPrice
instance ToJSON GoodsPrice

-- | Tax (Phase 1: stub)
data Tax = Tax
  { taxId :: !Int64
  , taxCode :: !Text
  , taxName :: !Text
  , taxRate :: !Double
  } deriving (Show, Eq, Generic)

instance FromJSON Tax
instance ToJSON Tax

-- | Currency (Phase 1: stub)
data Currency = Currency
  { currencyId :: !Int64
  , currencyCode :: !Text
  , currencyName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON Currency
instance ToJSON Currency

-- | AccPlan (Phase 1: stub)
data AccPlan = AccPlan
  { accPlanId :: !Int64
  , accPlanCode :: !Text
  , accPlanName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON AccPlan
instance ToJSON AccPlan

-- | AccTurn (Phase 1: stub)
data AccTurn = AccTurn
  { accTurnId :: !Int64
  , accTurnDebitAccount :: !Text
  , accTurnCreditAccount :: !Text
  , accTurnAmount :: !Double
  , accTurnDescription :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON AccTurn
instance ToJSON AccTurn

-- | AccTurnInput for creating/updating account turns
data AccTurnInput = AccTurnInput
  { atiDbtAccId :: !Int64
  , atiCrdAccId :: !Int64
  , atiAmount :: !Double
  , atiDescription :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON AccTurnInput
instance ToJSON AccTurnInput

-- | Employee (Phase 1: stub)
data Employee = Employee
  { employeeId :: !Int64
  , employeeCode :: !Text
  , employeeFirstName :: !Text
  , employeeLastName :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON Employee
instance ToJSON Employee

-- | Salary (Phase 1: stub)
data Salary = Salary
  { salaryId :: !Int64
  , salaryEmployeeId :: !Int64
  , salaryAmount :: !Double
  , salaryPeriod :: !Day
  } deriving (Show, Eq, Generic)

instance FromJSON Salary
instance ToJSON Salary

-- | StockMovement (Phase 1: stub)
data StockMovement = StockMovement
  { stockMovementId :: !Int64
  , stockMovementGoodsId :: !Int64
  , stockMovementWarehouseId :: !Int64
  , stockMovementType :: !Text
  , stockMovementQty :: !Double
  , stockMovementCreatedAt :: !UTCTime
  } deriving (Show, Eq, Generic)

instance FromJSON StockMovement
instance ToJSON StockMovement

-- | Timesheet (Phase 1: stub)
data Timesheet = Timesheet
  { timesheetId :: !Int64
  , timesheetEmployeeId :: !Int64
  , timesheetDate :: !Day
  , timesheetHours :: !Double
  , timesheetType :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON Timesheet
instance ToJSON Timesheet

-- Bill line (domain type)
data BillLine = BillLine
  { lineId :: Int64
  , lineBillId :: Int64
  , lineGoodId :: Int64
  , lineQtty :: Double
  , linePrice :: Double
  , lineDiscount :: Double
  , lineAmount :: Double
  } deriving (Show, Eq, Generic)

instance FromJSON BillLine
instance ToJSON BillLine

-- Payroll result (domain type)
data PayrollResult = PayrollResult
  { payrollResultId :: !Int64
  , payrollResultTenantId :: !Int64
  , payrollResultPeriod :: Day
  , payrollResultEmployeeId :: !Int64
  , payrollResultGross :: !Double
  , payrollResultDeductions :: !Double
  , payrollResultNet :: !Double
  , payrollResultIncomeTax :: !Double
  , payrollResultSocialTax :: !Double
  , payrollResultAdvance :: !Double
  , payrollResultBonus :: !Double
  , payrollResultVacationPay :: !Double
  , payrollResultSickPay :: !Double
  , payrollResultTotalToPay :: !Double
  , payrollResultCurrency :: !Text
  , payrollResultVersion :: !Int
  , payrollResultCreatedBy :: !(Maybe Int64)
  , payrollResultCreatedAt :: !UTCTime
  , payrollResultUpdatedAt :: !UTCTime
  } deriving (Show, Eq, Generic)

instance FromJSON PayrollResult
instance ToJSON PayrollResult

-- | Document register type (Phase 1: stub)
data DocumentRegisterType = DocumentRegisterType
  { drtId :: !Int64
  , drtCode :: !Text
  , drtName :: !Text
  , drtDescription :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON DocumentRegisterType
instance ToJSON DocumentRegisterType

-- | Workflow types (Phase 1: stub)
data Workflow = Workflow
  { workflowId :: !Int64
  , workflowCode :: !Text
  , workflowName :: !(Maybe Text)
  , workflowDescription :: !(Maybe Text)
  , workflowIsActive :: !Bool
  , workflowDefinition :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON Workflow
instance ToJSON Workflow

data WorkflowInput = WorkflowInput
  { wiInputData :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON WorkflowInput
instance ToJSON WorkflowInput

data WorkflowInstance = WorkflowInstance
  { wiInstanceId :: !Int64
  , wiWorkflowId :: !Int64
  , wiStatus :: !WorkflowStatus
  , wiCurrentStep :: !(Maybe Text)
  , wiContext :: !(Maybe Text)
  , wiStartedAt :: !(Maybe UTCTime)
  , wiCompletedAt :: !(Maybe UTCTime)
  } deriving (Show, Eq, Generic)

instance FromJSON WorkflowInstance
instance ToJSON WorkflowInstance

data WorkflowStatus
  = WorkflowPending
  | WorkflowRunning
  | WorkflowCompleted
  | WorkflowFailed
  deriving (Show, Eq, Generic)

instance FromJSON WorkflowStatus
instance ToJSON WorkflowStatus

-- | Classifier record types (Phase 1: stubs)
data OksmRecord = OksmRecord
  { oksmId :: !Int64
  , oksmCode :: !Text
  , oksmName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON OksmRecord
instance ToJSON OksmRecord

data OkvRecord = OkvRecord
  { okvId :: !Int64
  , okvCode :: !Text
  , okvName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON OkvRecord
instance ToJSON OkvRecord

data OkeiRecord = OkeiRecord
  { okeiId :: !Int64
  , okeiCode :: !Text
  , okeiName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON OkeiRecord
instance ToJSON OkeiRecord

data Okpd2Record = Okpd2Record
  { okpd2Id :: !Int64
  , okpd2Code :: !Text
  , okpd2Name :: !Text
  , okpd2ParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON Okpd2Record
instance ToJSON Okpd2Record

data Okved2Record = Okved2Record
  { okved2Id :: !Int64
  , okved2Code :: !Text
  , okved2Name :: !Text
  , okved2ParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON Okved2Record
instance ToJSON Okved2Record

data TnvedRecord = TnvedRecord
  { tnvedId :: !Int64
  , tnvedCode :: !Text
  , tnvedName :: !Text
  , tnvedParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON TnvedRecord
instance ToJSON TnvedRecord

data OkatoRecord = OkatoRecord
  { okatoId :: !Int64
  , okatoCode :: !Text
  , okatoName :: !Text
  , okatoParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON OkatoRecord
instance ToJSON OkatoRecord

data OktmoRecord = OktmoRecord
  { oktmoId :: !Int64
  , oktmoCode :: !Text
  , oktmoName :: !Text
  , oktmoParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON OktmoRecord
instance ToJSON OktmoRecord

data OkofRecord = OkofRecord
  { okofId :: !Int64
  , okofCode :: !Text
  , okofName :: !Text
  , okofParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON OkofRecord
instance ToJSON OkofRecord

data OkpRecord = OkpRecord
  { okpId :: !Int64
  , okpCode :: !Text
  , okpName :: !Text
  , okpParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON OkpRecord
instance ToJSON OkpRecord

data OkdpRecord = OkdpRecord
  { okdpId :: !Int64
  , okdpCode :: !Text
  , okdpName :: !Text
  , okdpParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON OkdpRecord
instance ToJSON OkdpRecord

data OksoRecord = OksoRecord
  { oksoId :: !Int64
  , oksoCode :: !Text
  , oksoName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON OksoRecord
instance ToJSON OksoRecord

data OkunRecord = OkunRecord
  { okunId :: !Int64
  , okunCode :: !Text
  , okunName :: !Text
  , okunParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON OkunRecord
instance ToJSON OkunRecord

data OkudRecord = OkudRecord
  { okudId :: !Int64
  , okudCode :: !Text
  , okudName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON OkudRecord
instance ToJSON OkudRecord

data OkfsRecord = OkfsRecord
  { okfsId :: !Int64
  , okfsCode :: !Text
  , okfsName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON OkfsRecord
instance ToJSON OkfsRecord

data OknpoRecord = OknpoRecord
  { oknpoId :: !Int64
  , oknpoCode :: !Text
  , oknpoName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON OknpoRecord
instance ToJSON OknpoRecord

-- | Stock balance row (API view over the @stock@ table)
data Stock = Stock
  { stockId :: !Int64
  , stockGoodsId :: !Int64
  , stockLocationId :: !Int64
  , stockQtty :: !Double
  } deriving (Show, Eq, Generic)

instance FromJSON Stock
instance ToJSON Stock

-- | Stock lot row (API view over the @lot@ table)
data Lot = Lot
  { lotId :: !Int64
  , lotGoodsId :: !Int64
  , lotRest :: !Double
  , lotCost :: !Double
  } deriving (Show, Eq, Generic)

instance FromJSON Lot
instance ToJSON Lot

-- | Tenant row (API view over the @tenants@ table)
data Tenant = Tenant
  { tenantId :: !Int64
  , tenantName :: !Text
  , tenantSlug :: !Text
  , tenantSchemaName :: !Text
  , tenantIsActive :: !Bool
  } deriving (Show, Eq, Generic)

instance FromJSON Tenant
instance ToJSON Tenant

-- | Tenant creation input
data TenantInput = TenantInput
  { tiTenantName :: !Text
  , tiSlug :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON TenantInput
instance ToJSON TenantInput

-- | User creation input
data UserInput = UserInput
  { uiUsername :: !Text
  , uiPasswordHash :: !Text
  , uiEmail :: !(Maybe Text)
  , uiStatus :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON UserInput
instance ToJSON UserInput

-- | Convenience accessor for the id carried by a 'MutationResult'
-- | CustomerEntity (DSL-generated entity)
data CustomerEntity = CustomerEntity
  { customerEntityId :: !T.Text
  , code :: !T.Text
  , name :: !T.Text
  , email :: !T.Text
  , creditLimit :: !T.Text
  , active :: !T.Text
  , createdAt :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON CustomerEntity
instance ToJSON CustomerEntity

-- | ProductionOrderEntity (DSL-generated entity)
data ProductionOrderEntity = ProductionOrderEntity
  { productionOrderEntityId :: !T.Text
  , number :: !T.Text
  , productId :: !T.Text
  , qty :: !T.Text
  , dueDate :: !T.Text
  , status :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON ProductionOrderEntity
instance ToJSON ProductionOrderEntity

-- | ReportConfigEntity (DSL-generated entity)
data ReportConfigEntity = ReportConfigEntity
  { reportConfigEntityId :: !T.Text
  , title :: !T.Text
  , query :: !T.Text
  , refreshMinutes :: !T.Text
  , enabled :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON ReportConfigEntity
instance ToJSON ReportConfigEntity

mrId :: MutationResult -> Maybe Int64
mrId = mutationId

-- | API request-body aliases: the client-facing shape equals the domain shape
type PaymentInput = Payment
type BillInput = Bill
type EmployeeInput = Employee
type SalaryInput = Salary
type StockMovementInput = StockMovement
type TimesheetInput = Timesheet
