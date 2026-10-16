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
  , getCurrentBalanceCached
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
import qualified Core.Accounting.RedisCache as RedisCache

-- | Unwrap the payload of a tagged-union event as written by
-- 'Infrastructure.EventStore.Accounting.appendAccountingEvent': @toJSON event@
-- stores @{\"tag\": ..., \"contents\": {fields...}}@. Payloads that are already
-- flat objects (legacy writers) are returned as-is; anything else is Nothing.
unwrappedFields :: A.Value -> Maybe (KM.KeyMap A.Value)
unwrappedFields eventData =
  case A.fromJSON eventData of
    A.Success (A.Object top) ->
      case KM.lookup "contents" top of
        Just (A.Object inner) -> Just inner
        _ -> Just top
    _ -> Nothing

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
--
-- The real producer ('Infrastructure.EventStore.Accounting.appendAccountingEvent')
-- stores @toJSON (AccountCreatedEvent ev)@ — a tagged union whose payload
-- sits under @\"contents\"@ with the record field names as keys
-- (@acCode@/@acName@/@acType@/@acParentId@). The code and name are read from
-- there (legacy flat payloads are still honoured); the previous version
-- discarded them and always set Nothing, so a replayed model carried no
-- account identity. 'armAccountType' stays Nothing on purpose: the producer's
-- @acType@ is a Text category (@\"asset\"@/@\"liability\"@/…) while the read
-- model expects an Int account-type id, and no mapping between the two exists
-- in the codebase — inventing one here would fabricate data. Same for
-- 'armCurrencyId' (the producer event has no currency field). Defining the
-- Text→Int mapping is a follow-up.
applyAccountCreated :: AccountReadModel -> ES.Event -> AccountReadModel
applyAccountCreated model event = model
  { armAccountId = ES.eventAggregateId event
  , armCode = entryCode
  , armName = entryName
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
  where
    eventData = ES.eventEventData event
    entryFields = unwrappedFields eventData
    lookupText key = entryFields >>= \obj ->
      case KM.lookup key obj of
        Just val -> case A.fromJSON val of
                      A.Success txt -> Just txt
                      _ -> Nothing
        Nothing -> Nothing
    entryCode = lookupText "acCode"
    entryName = lookupText "acName"

-- | Apply JournalEntryPosted event
--
-- The real producer ('Infrastructure.EventStore.Accounting.appendAccountingEvent')
-- stores @toJSON (JournalEntryPostedEvent ev)@ — a tagged union whose payload
-- sits under @"contents"@ with the record field names as keys
-- (@jepAmount@/@jepDebitAcc@/@jepCreditAcc@). The amount is read from there
-- (legacy payloads carrying only a top-level @"changeAmount"@ are still
-- honoured), and the sign follows the double-entry side of this model's
-- account: +amount on the debit side, -amount on the credit side, 0 for any
-- other account — mirroring the pure replay layer
-- 'Infrastructure.EventStore.Accounting.applyEvent'.
applyJournalEntryPosted :: AccountReadModel -> ES.Event -> AccountReadModel
applyJournalEntryPosted model event = model
  { armBalanceState = newBalanceState
  , armUpdatedAt = ES.eventOccurredAt event
  }
  where
    eventData = ES.eventEventData event
    entryFields = unwrappedFields eventData
    entryAmount = entryFields >>= \obj ->
      case KM.lookup "jepAmount" obj of
        Just val -> case A.fromJSON val of
                      A.Success amt -> Just amt
                      _ -> Nothing
        Nothing ->
          case KM.lookup "changeAmount" obj of
            Just val -> case A.fromJSON val of
                          A.Success amt -> Just amt
                          _ -> Nothing
            Nothing -> Nothing
    debitAccount = entryFields >>= \obj ->
      case KM.lookup "jepDebitAcc" obj of
        Just val -> case A.fromJSON val of
                      A.Success acc -> Just acc
                      _ -> Nothing
        Nothing -> Nothing
    creditAccount = entryFields >>= \obj ->
      case KM.lookup "jepCreditAcc" obj of
        Just val -> case A.fromJSON val of
                      A.Success acc -> Just acc
                      _ -> Nothing
        Nothing -> Nothing
    oldState = armBalanceState model
    changeAmount' = case (entryAmount, debitAccount, creditAccount) of
                      (Just amt, Just dAcc, Just cAcc)
                        | armAccountId model == dAcc -> amt
                        | armAccountId model == cAcc -> negate amt
                        | otherwise -> 0
                      (Just amt, Nothing, Nothing) -> amt
                      _ -> 0.0
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
--
-- No producer in the codebase writes a @BalanceAdjusted@ variant yet (the
-- 'Infrastructure.EventStore.Accounting.AccountingEvent' union has no such
-- constructor), so this is the documented contract for a future writer:
--
-- * @changeAmount@ is applied RELATIVE to the current balance and drives the
--   debit/credit totals (same sign convention as 'applyJournalEntryPosted').
-- * @newBalance@, when present, overrides the current balance absolutely;
--   when absent the balance keeps its old value plus @changeAmount@ — a
--   partial payload must never zero a live balance.
-- * Both payload shapes are honoured through 'unwrappedFields' (tagged-union
--   as written by 'Infrastructure.EventStore.Accounting.appendAccountingEvent'
--   and flat legacy objects), matching the other appliers.
applyBalanceAdjusted :: AccountReadModel -> ES.Event -> AccountReadModel
applyBalanceAdjusted model event = model
  { armBalanceState = newBalanceState
  , armUpdatedAt = ES.eventOccurredAt event
  }
  where
    eventData = ES.eventEventData event
    entryFields = unwrappedFields eventData
    lookupDouble key = entryFields >>= \obj ->
      case KM.lookup key obj of
        Just val -> case A.fromJSON val of
                      A.Success amt -> Just amt
                      _ -> Nothing
        Nothing -> Nothing
    changeAmount = lookupDouble "changeAmount"
    newBalance = lookupDouble "newBalance"
    oldState = armBalanceState model
    changeAmount' = fromMaybe 0.0 changeAmount
    newBalanceState = oldState
      { bsCurrentBalance = case newBalance of
                            Just nb -> nb
                            Nothing -> bsCurrentBalance oldState + changeAmount'
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
--
-- Note: this region completed a broken uncommitted WIP edit (case arms with
-- the record braces left dangling — the file did not parse). The guard's
-- intent (fail explicitly on an empty event list instead of crashing in
-- 'head') is preserved. The only caller ('replayAccountEvents') already
-- rejects the empty case with a Left, so this is defence in depth.
mkInitialModel :: Int64 -> [ES.Event] -> AccountReadModel
mkInitialModel accountId events =
  case events of
    (firstEvent:_) -> buildModel (ES.eventOccurredAt firstEvent)
    [] -> error "mkInitialModel: empty events list"
  where
    buildModel ts = AccountReadModel
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

-- | Get the current balance, consulting the Redis cache first (US-3-3).
--
-- A cache miss - or any Redis failure - falls back to rebuilding from the event
-- store, so the caller always gets a consistent answer. A freshly rebuilt value
-- is written back with the cache's TTL.
getCurrentBalanceCached :: RedisCache.RedisCache -> ConnectionPool -> Int64 -> Text -> IO (Either Text Double)
getCurrentBalanceCached cache pool accountId aggType = do
  cached <- RedisCache.getCachedBalance cache accountId
  case cached of
    Left _ -> rebuildAccountBalance pool accountId aggType
    Right (Just balance) -> pure (Right balance)
    Right Nothing -> do
      result <- rebuildAccountBalance pool accountId aggType
      case result of
        Right balance -> do
          _ <- RedisCache.putCachedBalance cache accountId balance
          pure result
        Left _ -> pure result

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