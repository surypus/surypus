{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Auth (
    login,
    logout,
)
where

import Surypus (Pool)

login :: Pool -> String -> String -> IO (Either String String)
login _ _ _ = return $ Right "stub-token"

logout :: Pool -> String -> IO (Either String ())
logout _ _ = return $ Right ()
