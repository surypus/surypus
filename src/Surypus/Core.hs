-- | Surypus Core module - aggregates main exports
{-# LANGUAGE OverloadedStrings #-}
module Surypus.Core (
    module DAL.Database,
    module DAL.EventStore,
    module Surypus.WebSocket
) where

import DAL.Database
import DAL.EventStore
import Surypus.WebSocket
