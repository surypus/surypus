{-# LANGUAGE OverloadedStrings #-}
-- | Kafka Producer (Phase 1: stub)
module Kafka.Producer where

import Data.Text (Text)
import Data.Int (Int64)

-- | Kafka producer configuration
data KafkaConfig = KafkaConfig
  { kcBrokers :: [Text]
  , kcClientId :: Text
  , kcTopic :: Text
  } deriving (Eq, Show)

-- | Kafka producer state (stub)
data KafkaProducer = KafkaProducer
  { producerConfig :: KafkaConfig
  }

-- | Create a new Kafka producer (stub)
newKafkaProducer :: KafkaConfig -> IO KafkaProducer
newKafkaProducer config = return (KafkaProducer config)

-- | Send a message to Kafka (stub)
sendMessage :: KafkaProducer -> Text -> Text -> IO (Either String ())
sendMessage _ _ _ = return (Right ())

-- | Close the Kafka producer (stub)
closeProducer :: KafkaProducer -> IO ()
closeProducer _ = return ()
