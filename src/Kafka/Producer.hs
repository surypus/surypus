{-# LANGUAGE OverloadedStrings #-}
module Kafka.Producer where

import EventBus
import Control.Monad.IO.Class (liftIO)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson ((.=), object)
import qualified Data.Aeson as Aeson
import Data.Int (Int64)

-- | Kafka producer configuration
data KafkaConfig = KafkaConfig
  { kcBrokers :: [Text]
  , kcClientId :: Text
  , kcTopic :: Text
  } deriving (Eq, Show)

-- | Kafka producer state
data KafkaProducer = KafkaProducer
  { kpConfig :: KafkaConfig
  , kpConnected :: Bool
  }

-- | Create Kafka producer (stub - would use kafka-client library)
newKafkaProducer :: KafkaConfig -> IO (Either Text KafkaProducer)
newKafkaProducer config = do
  -- TODO: Connect to Kafka brokers
  return $ Right $ KafkaProducer config False

-- | Produce message to Kafka topic
produceMessage :: KafkaProducer -> Text -> Aeson.Value -> IO (Either Text ())
produceMessage producer topic value = do
  -- TODO: Send to Kafka
  putStrLn $ "Would send to " ++ T.unpack topic ++ ": " ++ show value
  return $ Right ()

-- | Publish domain event to Kafka
publishToKafka :: KafkaProducer -> DomainEvent -> IO (Either Text ())
publishToKafka producer event = 
  let topic = "surypus-events"
  in produceMessage producer topic (Aeson.object ["type" .= deType event])
