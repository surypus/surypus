module Surypus.API.Bridge.AuthBridge where

import Data.Text (Text)
import qualified Surypus.Types.Auth as Auth

toInternalLoginInput :: Auth.LoginRequest -> Auth.LoginRequest
toInternalLoginInput = id

fromInternalLoginOutput :: Auth.LoginResponse -> Auth.LoginResponse
fromInternalLoginOutput = id

toInternalRefreshInput :: Auth.RefreshRequest -> Auth.RefreshRequest
toInternalRefreshInput = id

fromInternalRefreshOutput :: Auth.RefreshResponse -> Auth.RefreshResponse
fromInternalRefreshOutput = id
