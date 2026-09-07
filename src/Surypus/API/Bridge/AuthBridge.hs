-- | Surypus API Bridge AuthBridge (Phase 1: stub)
module Surypus.API.Bridge.AuthBridge where

import Data.Text (Text)

-- | Login request (stub)
data LoginRequest = LoginRequest
  { loginRequestUsername :: !Text
  , loginRequestPassword :: !Text
  } deriving (Show, Eq)

-- | Login response (stub)
data LoginResponse = LoginResponse
  { loginResponseToken :: !Text
  } deriving (Show, Eq)

-- | Refresh request (stub)
data RefreshRequest = RefreshRequest
  { refreshRequestToken :: !Text
  } deriving (Show, Eq)

-- | Refresh response (stub)
data RefreshResponse = RefreshResponse
  { refreshResponseToken :: !Text
  } deriving (Show, Eq)

toInternalLoginInput :: LoginRequest -> LoginRequest
toInternalLoginInput = id

fromInternalLoginOutput :: LoginResponse -> LoginResponse
fromInternalLoginOutput = id

toInternalRefreshInput :: RefreshRequest -> RefreshRequest
toInternalRefreshInput = id

fromInternalRefreshOutput :: RefreshResponse -> RefreshResponse
fromInternalRefreshOutput = id
