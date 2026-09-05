-- ============================================================================
-- SURYPUS ACCOUNTING READ MODEL
-- US-3-2: Account read-model replay from event stream
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RecordWildCards #-}

module Core.Accounting.ReadModel
  ( -- * Read Model Types
    AccountReadModel  (..)
  , BalanceState  (..)

    -- * Read Model Operations
  , replayAccountEvents
  , rebuildAccountBalance
  , getCurrentBalance
  , getAccountReadModel

    -- * Event Application
  , applyEvent
  , applyAccountCreated
  , applyJournalEntryPosted
  , applyBalanceAdjusted
  ) where

import Data.Time (UTCTime)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Foldable (foldl')
import Data.Maybe (fromMaybe)
import GHC.Generics (Generic)
import qualified Data.Aeson as A
import qualified Data.Aeson.KeyMap as KM
import qualified DAL.EventStore as ES
import DAL.ORMPool (ConnectionPool)

-- ============================================================================
-- READ MODEL TYPES
-- ============================================================================

-- | Balance state for an account
data BalanceState = BalanceState
  { bsAccountId :: Int64
  , bsCurrentBalance :: Double
  , bsDebitTotal :: Double
  , bsCreditTotal :: Double
  , bsLastUpdated :: UTCTime
  , bsEventCount :: Int
  } deriving (Show, Eq, Generic)

-- | Account read model containing all calculated state
data AccountReadModel = AccountReadModel
  { armAccountId :: Int64
  , armCode :: Maybe Text
  , armName :: Maybe Text
  , armAccountType :: Maybe Int
  , armCurrencyId :: Maybe Int64
  , armBalanceState :: BalanceState
  , armCreatedAt :: UTCTime
  , armUpdatedAt :: UTCTime
  } deriving (Show, Eq, Generic)

-- ============================================================================
-- EVENT APPLICATION
-- ============================================================================

-- | Apply a single event to the read model
applyEvent :: AccountReadModel -> ES.Event -> AccountReadModel
applyEvent model event
  | ES.eventEventType event == "AccountCreated" = applyAccountCreated model event
  | ES.eventEventType event == "JournalEntryPosted" = applyJournalEntryPosted model event
  | ES.eventEventType event == "BalanceAdjusted" = applyBalanceAdjusted model event
  | otherwise = model

-- | Apply AccountCreated event
applyAccountCreated :: AccountReadModel -> ES.Event -> AccountReadModel
applyAccountCreated model event = model
  { armAccountId = ES.eventAggregateId event
  , armCode = Nothing
  , armName = Nothing
  , armAccountType = Nothing
  , armCurrencyId = Nothing
  , armBalanceState = BalanceState
      { bsAccountId = ES.eventAggregateId event
      , bsCurrentBalance = 0.0
      , bsDebitTotal = 0.0
      , bsCreditTotal = 0.0
      , bsLastUpdated = ES.eventOccurredAt event
      , bsEventCount = 1
      }
  , armCreatedAt = ES.eventOccurredAt event
  , armUpdatedAt = ES.eventOccurredAt event
  }

-- | Apply JournalEntryPosted event
applyJournalEntryPosted :: AccountReadModel -> ES.Event -> AccountReadModel
applyJournalEntryPosted model event = model
  { armBalanceState = newBalanceState
  , armUpdatedAt = ES.eventOccurredAt event
  }
  where
    eventData = ES.eventEventData event
    changeAmount = case A.fromJSON eventData of
                     A.Success (A.Object obj) ->
                       case KM.lookup "changeAmount" obj of
                         Just val -> case A.fromJSON val of
                           A.Success amt -> Just amt
                           _ -> Nothing
                         Nothing -> Nothing
                     _ -> Nothing
    oldState = armBalanceState model
    changeAmount' = fromMaybe 0.0 changeAmount
    newBalanceState = oldState
      { bsCurrentBalance = bsCurrentBalance oldState + changeAmount'
      , bsDebitTotal = if changeAmount' > 0
                       then bsDebitTotal oldState + changeAmount'
                       else bsDebitTotal oldState
      , bsCreditTotal = if changeAmount' < 0
                        then bsCreditTotal oldState + abs changeAmount'
                        else bsCreditTotal oldState
      , bsLastUpdated = ES.eventOccurredAt event
      , bsEventCount = bsEventCount oldState + 1
      }

-- | Apply BalanceAdjusted event
applyBalanceAdjusted :: AccountReadModel -> ES.Event -> AccountReadModel
applyBalanceAdjusted model event = model
  { armBalanceState = newBalanceState
  , armUpdatedAt = ES.eventOccurredAt event
  }
  where
    eventData = ES.eventEventData event
    changeAmount = case A.fromJSON eventData of
                     A.Success (A.Object obj) ->
                       case KM.lookup "changeAmount" obj of
                         Just val -> case A.fromJSON val of
                           A.Success amt -> Just amt
                           _ -> Nothing
                         Nothing -> Nothing
                     _ -> Nothing
    newBalance = case A.fromJSON eventData of
                   A.Success (A.Object obj) ->
                     case KM.lookup "newBalance" obj of
                       Just val -> case A.fromJSON val of
                         A.Success amt -> Just amt
                         _ -> Nothing
                       Nothing -> Nothing
                   _ -> Nothing
    oldState = armBalanceState model
    changeAmount' = fromMaybe 0.0 changeAmount
    newBalance' = fromMaybe 0.0 newBalance
    newBalanceState = oldState
      { bsCurrentBalance = newBalance'
      , bsDebitTotal = if changeAmount' > 0
                       then bsDebitTotal oldState + changeAmount'
                       else bsDebitTotal oldState
      , bsCreditTotal = if changeAmount' < 0
                        then bsCreditTotal oldState + abs changeAmount'
                        else bsCreditTotal oldState
      , bsLastUpdated = ES.eventOccurredAt event
      , bsEventCount = bsEventCount oldState + 1
      }

-- ============================================================================
-- READ MODEL OPERATIONS
-- ============================================================================

-- | Create initial model from the first event in a list
mkInitialModel :: Int64 -> [ES.Event] -> AccountReadModel
mkInitialModel accountId events =
   let firstEvent = head events
       ts = ES.eventOccurredAt firstEvent
   in AccountReadModel
    { armAccountId = accountId
    , armCode = Nothing
    , armName = Nothing
    , armAccountType = Nothing
    , armCurrencyId = Nothing
    , armBalanceState = BalanceState
        { bsAccountId = accountId
        , bsCurrentBalance = 0.0
        , bsDebitTotal = 0.0
        , bsCreditTotal = 0.0
        , bsLastUpdated = ts
        , bsEventCount = 0
        }
    , armCreatedAt = ts
    , armUpdatedAt = ts
    }

-- | Replay events from the event store to build read model
replayAccountEvents :: ConnectionPool -> Int64 -> Text -> IO (Either Text AccountReadModel)
replayAccountEvents pool accountId aggType = do
  result <- ES.getEvents pool accountId aggType
  case result of
    Left err -> pure (Left err)
    Right [] -> pure (Left "No events found for account")
    Right es -> do
      let initialModel = mkInitialModel accountId es
          finalModel = foldl' applyEvent initialModel es
      pure (Right finalModel)

-- | Rebuild account balance from event stream
rebuildAccountBalance :: ConnectionPool -> Int64 -> Text -> IO (Either Text Double)
rebuildAccountBalance pool accountId aggType = do
  result <- replayAccountEvents pool accountId aggType
  case result of
    Left err -> pure (Left err)
    Right model -> pure (Right (bsCurrentBalance (armBalanceState model)))

-- | Get current balance for an account
getCurrentBalance :: ConnectionPool -> Int64 -> Text -> IO (Either Text Double)
getCurrentBalance pool = rebuildAccountBalance pool

-- | Get full account read model
getAccountReadModel :: ConnectionPool -> Int64 -> Text -> IO (Either Text AccountReadModel)
getAccountReadModel pool = replayAccountEvents pool


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- | Validate that the read model is in a consistent state
validateReadModel :: AccountReadModel -> Either Text ()
validateReadModel model
  | bsCurrentBalance balanceState < 0 = Left "Account balance cannot be negative"
  | bsEventCount balanceState == 0 = Left "Account has no events"
  | otherwise = Right ()
  where
    balanceState = armBalanceState model