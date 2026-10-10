{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module DAL.Types where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime)
import GHC.Generics (Generic)

-- Generated from dsl/schema.yaml
-- DO NOT EDIT MANUALLY

-- DSL entities:
-- Entity: PersonEntity
-- SQL table: person
data PersonEntity = PersonEntity
  { personEntityId :: !T.Text
  , code :: !T.Text
  , name :: !T.Text
  , inn :: !T.Text
  , kpp :: !T.Text
  , personType :: !T.Text
  , status :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON (PersonEntity)
instance ToJSON (PersonEntity)

-- Entity: CustomerEntity
-- SQL table: customer
data CustomerEntity = CustomerEntity
  { customerEntityId :: !T.Text
  , code :: !T.Text
  , name :: !T.Text
  , email :: !T.Text
  , creditLimit :: !T.Text
  , active :: !T.Text
  , createdAt :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON (CustomerEntity)
instance ToJSON (CustomerEntity)

-- Entity: ProductionOrderEntity
-- SQL table: production_order
data ProductionOrderEntity = ProductionOrderEntity
  { productionOrderEntityId :: !T.Text
  , number :: !T.Text
  , productId :: !T.Text
  , qty :: !T.Text
  , dueDate :: !T.Text
  , status :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON (ProductionOrderEntity)
instance ToJSON (ProductionOrderEntity)

-- Entity: ReportConfigEntity
-- SQL table: report_config
data ReportConfigEntity = ReportConfigEntity
  { reportConfigEntityId :: !T.Text
  , title :: !T.Text
  , query :: !T.Text
  , refreshMinutes :: !T.Text
  , enabled :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON (ReportConfigEntity)
instance ToJSON (ReportConfigEntity)

-- Entity: BillEntity
-- SQL table: bill
data BillEntity = BillEntity
  { billEntityId :: !T.Text
  , billEntityNumber :: !T.Text
  , billEntityCustomerId :: !T.Text
  , billEntityTotal :: !T.Text
  , billEntityStatus :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON (BillEntity)
instance ToJSON (BillEntity)

-- Entity: TaxEntity
-- SQL table: tax
data TaxEntity = TaxEntity
  { taxEntityId :: !T.Text
  , taxEntityCode :: !T.Text
  , taxEntityName :: !T.Text
  , taxEntityRate :: !T.Text
  } deriving (Show, Eq, Generic)

instance FromJSON (TaxEntity)
instance ToJSON (TaxEntity)

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
  , billDate :: !Data.Time.Day
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
  , orderType :: !(Maybe Text)
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
  , userPassword :: !(Maybe Text)
  , userEmail :: !(Maybe Text)
  , userPersonId :: !(Maybe Int64)
  , userStatus :: !Text
  , userTenantId :: !Int64
  } deriving (Show, Eq, Generic)

instance FromJSON User
instance ToJSON User

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
  { payrollResultId :: Int64
  , payrollResultTenantId :: Int64
  , payrollResultPeriod :: Day
  , payrollResultEmployeeId :: Int64
  , payrollResultGross :: Double
  , payrollResultDeductions :: Double
  , payrollResultNet :: Double
  , payrollResultIncomeTax :: Double
  , payrollResultSocialTax :: Double
  , payrollResultAdvance :: Double
  , payrollResultBonus :: Double
  , payrollResultVacationPay :: Double
  , payrollResultSickPay :: Double
  , payrollResultTotalToPay :: Double
  , payrollResultCurrency :: Text
  , payrollResultVersion :: Int
  , payrollResultCreatedBy :: Maybe Int64
  , payrollResultCreatedAt :: UTCTime
  , payrollResultUpdatedAt :: UTCTime
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

data WorkflowInput = WorkflowInput
  { wiInputData :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

data WorkflowInstance = WorkflowInstance
  { wiInstanceId :: !Int64
  , wiWorkflowId :: !Int64
  , wiStatus :: !WorkflowStatus
  , wiCurrentStep :: !(Maybe Text)
  , wiContext :: !(Maybe Text)
  , wiStartedAt :: !(Maybe UTCTime)
  , wiCompletedAt :: !(Maybe UTCTime)
  } deriving (Show, Eq, Generic)

data WorkflowStatus = WorkflowPending | WorkflowRunning | WorkflowCompleted | WorkflowFailed
  deriving (Show, Eq, Generic)

-- | Classifier record types (Phase 1: stubs)
data OksmRecord = OksmRecord
  { oksmId :: !Int64
  , oksmCode :: !Text
  , oksmName :: !Text
  } deriving (Show, Eq, Generic)

data OkvRecord = OkvRecord
  { okvId :: !Int64
  , okvCode :: !Text
  , okvName :: !Text
  } deriving (Show, Eq, Generic)

data OkeiRecord = OkeiRecord
  { okeiId :: !Int64
  , okeiCode :: !Text
  , okeiName :: !Text
  } deriving (Show, Eq, Generic)

data Okpd2Record = Okpd2Record
  { okpd2Id :: !Int64
  , okpd2Code :: !Text
  , okpd2Name :: !Text
  , okpd2ParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

data Okved2Record = Okved2Record
  { okved2Id :: !Int64
  , okved2Code :: !Text
  , okved2Name :: !Text
  , okved2ParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

data TnvedRecord = TnvedRecord
  { tnvedId :: !Int64
  , tnvedCode :: !Text
  , tnvedName :: !Text
  , tnvedParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

data OkatoRecord = OkatoRecord
  { okatoId :: !Int64
  , okatoCode :: !Text
  , okatoName :: !Text
  , okatoParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

data OktmoRecord = OktmoRecord
  { oktmoId :: !Int64
  , oktmoCode :: !Text
  , oktmoName :: !Text
  , oktmoParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

data OkofRecord = OkofRecord
  { okofId :: !Int64
  , okofCode :: !Text
  , okofName :: !Text
  , okofParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

data OkpRecord = OkpRecord
  { okpId :: !Int64
  , okpCode :: !Text
  , okpName :: !Text
  , okpParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

data OkdpRecord = OkdpRecord
  { okdpId :: !Int64
  , okdpCode :: !Text
  , okdpName :: !Text
  , okdpParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

data OksoRecord = OksoRecord
  { oksoId :: !Int64
  , oksoCode :: !Text
  , oksoName :: !Text
  } deriving (Show, Eq, Generic)

data OkunRecord = OkunRecord
  { okunId :: !Int64
  , okunCode :: !Text
  , okunName :: !Text
  , okunParentCode :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

data OkudRecord = OkudRecord
  { okudId :: !Int64
  , okudCode :: !Text
  , okudName :: !Text
  } deriving (Show, Eq, Generic)

data OkfsRecord = OkfsRecord
  { okfsId :: !Int64
  , okfsCode :: !Text
  , okfsName :: !Text
  } deriving (Show, Eq, Generic)

data OknpoRecord = OknpoRecord
  { oknpoId :: !Int64
  , oknpoCode :: !Text
  , oknpoName :: !Text
  } deriving (Show, Eq, Generic)

-- Generated by surypus-codegen
