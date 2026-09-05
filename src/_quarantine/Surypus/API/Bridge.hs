module Surypus.API.Bridge (Bridge (..), bridgeToCore, toCore) where

data Bridge a = Bridge {unBridge :: a} deriving (Show)

bridgeToCore :: a -> Bridge a
bridgeToCore = Bridge

toCore :: Bridge a -> a
toCore (Bridge x) = x
