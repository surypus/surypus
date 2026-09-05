{-# LANGUAGE OverloadedStrings #-}

module Surypus.EventBridge
  ( startEventBridge,
    publishEvent,
    subscribeEvent,
    unsubscribeEvent,
    DomainEvent (..),
    EventBridge,
    newEventBridge,
    runEventBridge,
  )
where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM (TQueue, atomically, newTQueue, readTQueue, tryReadTQueue, writeTQueue)
import Control.Monad (forever, void)
import Data.Aeson (Value)
import Data.Text (Text)
import qualified Data.Text as T

data DomainEvent = DomainEvent
  { deName :: Text,
    dePayload :: Value
  }
  deriving (Show, Eq)

type EventHandler = DomainEvent -> IO ()

data Subscription = Subscription
  { subEventName :: Text,
    subQueue :: TQueue DomainEvent
  }

data EventBridge = EventBridge
  { ebSubscribers :: TQueue Subscription,
    ebEventQueue :: TQueue DomainEvent
  }

newEventBridge :: IO EventBridge
newEventBridge = do
  subs <- atomically newTQueue
  events <- atomically newTQueue
  pure $ EventBridge subs events

startEventBridge :: IO EventBridge
startEventBridge = do
  bridge <- newEventBridge
  _ <- forkIO $ eventDispatcher bridge
  putStrLn "EventBridge started with STM dispatcher"
  pure bridge

runEventBridge :: EventBridge -> IO ()
runEventBridge bridge = do
  bridge' <- startEventBridge
  forever $ threadDelay 1000000

eventDispatcher :: EventBridge -> IO ()
eventDispatcher bridge = forever $ do
  event <- atomically $ readTQueue (ebEventQueue bridge)
  putStrLn $ "EventBridge dispatching: " <> T.unpack (deName event)

subscribeEvent :: EventBridge -> Text -> IO (TQueue DomainEvent)
subscribeEvent bridge eventName = do
  q <- atomically newTQueue
  let sub = Subscription eventName q
  atomically $ writeTQueue (ebSubscribers bridge) sub
  pure q

unsubscribeEvent :: EventBridge -> Text -> TQueue DomainEvent -> IO ()
unsubscribeEvent _bridge _eventName _queue = pure ()

publishEvent :: DomainEvent -> IO ()
publishEvent event = do
  putStrLn $ "EventBridge publishing: " <> T.unpack (deName event)
  pure ()

getHandlerQueue :: EventBridge -> Text -> IO (Maybe (TQueue DomainEvent))
getHandlerQueue _bridge _eventName = pure Nothing
