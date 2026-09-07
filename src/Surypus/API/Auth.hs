{-# LANGUAGE OverloadedStrings #-}
-- | Surypus API Auth (Phase 1: stub)
module Surypus.API.Auth
  ( login
  , logout
  ) where

import Data.Text (Text)

-- | Login (stub)
login :: Text -> Text -> Text -> IO (Either Text Text)
login _ _ _ = return $ Right "stub-token"

-- | Logout (stub)
logout :: Text -> Text -> IO (Either Text ())
logout _ _ = return $ Right ()
