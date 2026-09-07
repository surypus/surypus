{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE LambdaCase #-}

module Surypus.API.Push
    ( PushSubscription(..)
    , PushSubscriptionRequest(..)
    , subscribe
    , unsubscribe
    , sendPush
    , PushStore
    , newPushStore
    ) where

import Control.Concurrent.STM (TVar, newTVarIO, readTVarIO, modifyTVar', atomically)
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)
import qualified Data.Map.Strict as M

data PushSubscription = PushSubscription
    { psUserId   :: !Int64
    , psEndpoint :: !Text
    , psP256dh   :: !Text
    , psAuth     :: !Text
    }
    deriving (Show, Eq, Generic)
instance ToJSON PushSubscription
instance FromJSON PushSubscription

data PushSubscriptionRequest = PushSubscriptionRequest
    { psrEndpoint :: !Text
    , psrP256dh   :: !Text
    , psrAuth     :: !Text
    }
    deriving (Show, Eq, Generic)
instance FromJSON PushSubscriptionRequest

type PushStore = TVar (M.Map Int64 PushSubscription)

newPushStore :: IO PushStore
newPushStore = newTVarIO M.empty

subscribe :: PushStore -> Int64 -> PushSubscriptionRequest -> IO ()
subscribe store userId req = atomically $ modifyTVar' store $
    M.insert userId PushSubscription
        { psUserId = userId
        , psEndpoint = psrEndpoint req
        , psP256dh = psrP256dh req
        , psAuth = psrAuth req
        }

unsubscribe :: PushStore -> Int64 -> IO ()
unsubscribe store userId = atomically $ modifyTVar' store $ M.delete userId

sendPush :: PushStore -> Int64 -> Text -> Text -> IO ()
sendPush store userId title body = do
    getSubscription store userId >>= \case
        Nothing -> pure ()
        Just sub -> do
            let endpoint = psEndpoint sub
            putStrLn $ "[push] Would send to " ++ show endpoint
            putStrLn $ "[push] Title: " ++ show title
            putStrLn $ "[push] Body: " ++ show body

getSubscription :: PushStore -> Int64 -> IO (Maybe PushSubscription)
getSubscription store userId = M.lookup userId <$> readTVarIO store
