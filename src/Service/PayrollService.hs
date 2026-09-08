-- | Payroll Service — orchestrates payroll calculations and persistence
-- Uses Data.Decimal for all monetary amounts (PYR-02)
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Service.PayrollService
  ( PayrollRequest(..)
  , PayrollResult(..)
  , calculatePayroll
  , calculateAndSavePayroll
  , calcVacationPay
  , calcSickPay
  , calculateYearEndSummary
  , PayrollEvent(..)
  , applyPayrollEvent
  , replayPayroll
  , toPayrollEvent
  , emptyPayrollState
  ) where

import Data.Aeson (ToJSON, FromJSON, object, (.=), toJSON, Value)
import qualified Data.Aeson as A
import Data.Decimal (Decimal)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Database.Persist.Postgresql (ConnectionPool)
import Core.Payroll.Calculation
import DAL.Payroll (savePayrollResult)
import DAL.EventStore (appendEvent, currentEventSchemaVersion)
import DAL.Types (QueryResult(..), PayrollResult(..))

-- | Payroll calculation request
data PayrollRequest = PayrollRequest
  { prEmployeeId :: Int64
  , prTenantId :: Int64
  , prPeriod :: Day
  , prBaseSalary :: Decimal
  , prBonus :: Decimal
  , prDaysWorked :: Int
  , prVacationDays :: Int
  , prSickDays :: Int
  }

-- | Payroll calculation result (domain type, matches DAL.PayrollResult fields)
data PayrollResult = PayrollResult
  { prCalcEmployeeId :: Int64
  , prCalcTenantId :: Int64
  , prCalcPeriod :: Day
  , prGrossSalary :: Decimal
  , prIncomeTax :: Decimal
  , prSocialTax :: Decimal
  , prDeductions :: Decimal
  , prNetSalary :: Decimal
  , prAdvance :: Decimal
  , prBonusAmount :: Decimal
  , prVacationPay :: Decimal
  , prSickPay :: Decimal
  , prTotalToPay :: Decimal
  , prCurrency :: Text
  } deriving (Show, Eq)

instance ToJSON PayrollResult where
  toJSON r = A.object
    [ "employeeId" .= prCalcEmployeeId r
    , "tenantId"   .= prCalcTenantId r
    , "period"     .= prCalcPeriod r
    , "gross"      .= show (prGrossSalary r)
    , "incomeTax"  .= show (prIncomeTax r)
    , "socialTax"  .= show (prSocialTax r)
    , "deductions" .= show (prDeductions r)
    , "net"        .= show (prNetSalary r)
    , "advance"    .= show (prAdvance r)
    , "bonus"      .= show (prBonusAmount r)
    , "vacationPay" .= show (prVacationPay r)
    , "sickPay"    .= show (prSickPay r)
    , "totalToPay" .= show (prTotalToPay r)
    , "currency"   .= prCurrency r
    ]

-- | Calculate full payroll for an employee
calculatePayroll :: PayrollRequest -> PayrollResult
calculatePayroll req =
  let gross = prBaseSalary req
      incomeTax = calcIncomeTax gross
      socialTax = calcSocialTax gross
      deductions = incomeTax + socialTax
      netSalary = gross - deductions
      advance = calcMonthlyAdvance gross
      bonus = prBonus req
      vacationPay = calcVacationPay (prVacationDays req) gross
      sickPay = calcSickPay (prSickDays req) gross
      totalToPay = netSalary + bonus + vacationPay + sickPay
  in PayrollResult
    { prCalcEmployeeId = prEmployeeId req
    , prCalcTenantId = prTenantId req
    , prCalcPeriod = prPeriod req
    , prGrossSalary = gross
    , prIncomeTax = incomeTax
    , prSocialTax = socialTax
    , prDeductions = deductions
    , prNetSalary = netSalary
    , prAdvance = advance
    , prBonusAmount = bonus
    , prVacationPay = vacationPay
    , prSickPay = sickPay
    , prTotalToPay = totalToPay
    , prCurrency = "RUB"
    }

-- | Calculate and persist payroll result, emitting a PayrollCalculated
-- domain event for the event-sourced read model (PYR-01 + event sourcing).
calculateAndSavePayroll :: ConnectionPool -> PayrollRequest -> Int64 -> IO (QueryResult PayrollResult)
calculateAndSavePayroll pool req userId =
  let result = calculatePayroll req
  in do
    dbRes <- savePayrollResult pool
      (prCalcTenantId result)
      (prCalcPeriod result)
      (prCalcEmployeeId result)
      (prGrossSalary result)
      (prDeductions result)
      (prNetSalary result)
      (prIncomeTax result)
      (prSocialTax result)
      (prAdvance result)
      (prBonusAmount result)
      (prVacationPay result)
      (prSickPay result)
      (prTotalToPay result)
      (prCurrency result)
      userId
    -- Emit the domain event. The payroll aggregate is keyed by employee id;
    -- the event carries the full calculated result plus who triggered it.
    let eventData = toJSON result
        eventMeta = object
          [ "userId"   .= userId
          , "tenantId" .= prCalcTenantId result
          , "period"   .= show (prCalcPeriod result)
          ]
    _ <- appendEvent pool
      (prCalcEmployeeId result)   -- aggregate id (per-employee stream)
      "payroll"                   -- aggregate type
      "PayrollCalculated"         -- event type
      1                           -- event version
      currentEventSchemaVersion  -- schema version
      eventData
      (Just eventMeta)
      (prCalcEmployeeId result)   -- sequence number (one stream per employee)
    -- The DB write is authoritative for the response; event emission is
    -- best-effort here (a production system would wrap both in one transaction
    -- or use the event as the source of truth and project from it).
    pure dbRes

-- | Calculate vacation pay (avg daily * days * 1.0)
calcVacationPay :: Int -> Decimal -> Decimal
calcVacationPay days monthlySalary = (monthlySalary / 29.3) * fromIntegral days

-- | Calculate sick pay (avg daily * days, employer + social portions)
calcSickPay :: Int -> Decimal -> Decimal
calcSickPay days monthlySalary
  | days <= 0 = 0
  | days <= 3 = (monthlySalary / 29.3) * 0.60 * fromIntegral days
  | otherwise = let emp = (monthlySalary / 29.3) * 0.60 * 3
                    soc = (monthlySalary / 29.3) * 0.80 * fromIntegral (days - 3)
                in emp + soc

-- | Calculate year-end payroll summary
calculateYearEndSummary :: [PayrollResult] -> Decimal
calculateYearEndSummary results =
  sum (map prTotalToPay results)

--------------------------------------------------------------------------------
-- Event sourcing: fold payroll events back into the latest state.
--
-- The authoritative write still goes to the relational table, but every run
-- emits a PayrollCalculated event (see calculateAndSavePayroll). The fold below
-- lets a read model be rebuilt purely from the event stream, which is the core
-- promise of event sourcing: current state = fold(empty, events).

-- | A payroll domain event.
data PayrollEvent
  = PayrollCalculated PayrollResult  -- ^ a calculated payroll run
  deriving (Show, Eq)

-- | Initial (empty) payroll aggregate state for a single employee stream.
emptyPayrollState :: Maybe PayrollResult
emptyPayrollState = Nothing

-- | Apply one event to the running payroll aggregate, keeping only the latest
-- calculation (payroll is a snapshot per period; the newest event wins).
applyPayrollEvent :: Maybe PayrollResult -> PayrollEvent -> Maybe PayrollResult
applyPayrollEvent _ (PayrollCalculated r) = Just r

-- | Replay an ordered event stream into the latest payroll state.
replayPayroll :: [PayrollEvent] -> Maybe PayrollResult
replayPayroll = foldl applyPayrollEvent emptyPayrollState

-- | Project a 'PayrollResult' into a 'PayrollEvent' (used when re-emitting or
-- testing the fold without a live event store).
toPayrollEvent :: PayrollResult -> PayrollEvent
toPayrollEvent = PayrollCalculated
