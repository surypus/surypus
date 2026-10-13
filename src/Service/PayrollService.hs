-- | Payroll Service — orchestrates payroll calculations and persistence
-- Uses Data.Decimal for all monetary amounts (PYR-02)
{-# LANGUAGE OverloadedStrings #-}

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

import Data.Aeson (object, (.=), toJSON)
import qualified Data.Aeson as A
import Data.Decimal (Decimal)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime, getCurrentTime)
import Database.Persist.Postgresql (ConnectionPool)
import Core.Payroll.Calculation
import DAL.Payroll (savePayrollResult)
import DAL.Types (QueryResult(..), PayrollResult(..))
import DAL.EventStore (appendEvent, currentEventSchemaVersion, Event(..))

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
    { payrollResultId = 0
    , payrollResultEmployeeId = prEmployeeId req
    , payrollResultTenantId = prTenantId req
    , payrollResultPeriod = prPeriod req
    , payrollResultGross = realToFrac gross
    , payrollResultIncomeTax = realToFrac incomeTax
    , payrollResultSocialTax = realToFrac socialTax
    , payrollResultDeductions = realToFrac deductions
    , payrollResultNet = realToFrac netSalary
    , payrollResultAdvance = realToFrac advance
    , payrollResultBonus = realToFrac bonus
    , payrollResultVacationPay = realToFrac vacationPay
    , payrollResultSickPay = realToFrac sickPay
    , payrollResultTotalToPay = realToFrac totalToPay
    , payrollResultCurrency = "RUB"
    , payrollResultVersion = 0
    , payrollResultCreatedBy = Nothing
    , payrollResultCreatedAt = read "1970-01-01 00:00:00 UTC"
    , payrollResultUpdatedAt = read "1970-01-01 00:00:00 UTC"
    }

-- | Calculate and persist payroll result, emitting a PayrollCalculated
-- domain event for the event-sourced read model (PYR-01 + event sourcing).
calculateAndSavePayroll :: ConnectionPool -> PayrollRequest -> Int64 -> IO (QueryResult PayrollResult)
calculateAndSavePayroll pool req userId = do
  now <- getCurrentTime
  let result = calculatePayroll req
  dbRes <- savePayrollResult pool
    (payrollResultTenantId result)
    (payrollResultPeriod result)
    (payrollResultEmployeeId result)
    (realToFrac (payrollResultGross result) :: Double)
    (realToFrac (payrollResultDeductions result) :: Double)
    (realToFrac (payrollResultNet result) :: Double)
    (realToFrac (payrollResultIncomeTax result) :: Double)
    (realToFrac (payrollResultSocialTax result) :: Double)
    (realToFrac (payrollResultAdvance result) :: Double)
    (realToFrac (payrollResultBonus result) :: Double)
    (realToFrac (payrollResultVacationPay result) :: Double)
    (realToFrac (payrollResultSickPay result) :: Double)
    (realToFrac (payrollResultTotalToPay result) :: Double)
    (payrollResultCurrency result)
    userId
  let eventData = toJSON result
      eventMeta = object
        [ "userId"   .= userId
        , "tenantId" .= payrollResultTenantId result
        , "period"   .= show (payrollResultPeriod result)
        ]
      event = Event
        { eventAggregateId = payrollResultEmployeeId result
        , eventAggregateType = "payroll"
        , eventEventType = "PayrollCalculated"
        , eventEventVersion = 1
        , eventSchemaVersion = currentEventSchemaVersion
        , eventEventData = eventData
        , eventEventMetadata = Just eventMeta
        , eventSequenceNumber = payrollResultEmployeeId result
        , eventOccurredAt = now
        , eventCreatedAt = now
        }
  _ <- appendEvent pool event
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
calculateYearEndSummary :: [PayrollResult] -> Double
calculateYearEndSummary results =
  sum (map payrollResultTotalToPay results)

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
