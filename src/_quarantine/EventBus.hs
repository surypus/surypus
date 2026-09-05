{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
module EventBus where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (Value)
import Control.Concurrent.Chan
import Control.Monad (when)
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUIDv4
import Data.Time (UTCTime, getCurrentTime)

-- | Domain event type
data DomainEvent = DomainEvent
  { deId :: Text
  , deType :: Text
  , deTimestamp :: UTCTime
  , dePayload :: Value
  , deSource :: Text
  } deriving (Eq, Show)

-- | Event bus for publishing events
data EventBus = EventBus
  { ebChan :: Chan DomainEvent
  , ebKafkaEnabled :: Bool
  }

-- | Create new event bus
newEventBus :: Bool -> IO EventBus
newEventBus kafkaEnabled = do
  chan <- newChan
  pure $ EventBus chan kafkaEnabled

-- | Publish event to bus
publishEvent :: EventBus -> DomainEvent -> IO ()
publishEvent EventBus{..} event = do
  writeChan ebChan event
  when ebKafkaEnabled $ do
    -- TODO: Send to Kafka
    putStrLn $ "Would send to Kafka: " <> show (deType event)

-- | Create domain event
createEvent :: Text -> Value -> Text -> IO DomainEvent
createEvent eventType payload source = do
  uuid <- T.pack . UUID.toString <$> UUIDv4.nextRandom
  timestamp <- getCurrentTime
  pure $ DomainEvent uuid eventType timestamp payload source

-- | Start event processor
startProcessor :: EventBus -> IO ()
startProcessor EventBus{..} = do
  event <- readChan ebChan
  -- TODO: Process event (Kafka, DB, etc.)
  startProcessor EventBus{..}
