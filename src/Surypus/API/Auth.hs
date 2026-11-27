{-# LANGUAGE OverloadedStrings #-}
-- | Surypus API Auth — real authentication via DAL and signed JWTs.
module Surypus.API.Auth
  ( login
  , logout
  ) where

import qualified DAL.Mutations as DAL
import DAL.Types (QueryResult (..))
import Data.Text (Text)
import Database.Persist.Postgresql (ConnectionPool)
import qualified Surypus.JWT.Token as JWT

-- | Authenticate a user and issue a signed token. The tenant argument is
-- accepted for API compatibility; user lookup is currently global.
login :: ConnectionPool -> Text -> Text -> Text -> IO (Either Text Text)
login pool _tenant username password = do
  result <- DAL.authenticateUser pool username password
  case result of
    QuerySuccess (Just user) -> Right <$> JWT.generateToken pool user
    QuerySuccess Nothing -> pure (Left "invalid credentials")
    QueryError e -> pure (Left e)
    QueryResults _ _ -> pure (Left "unexpected authentication result")

-- | Stateless tokens cannot be revoked server-side without a revocation
-- store, so logout validates the presented token and acknowledges it.
logout :: Text -> Text -> IO (Either Text ())
logout _tenant token = do
  result <- JWT.verifyToken token
  pure $ case result of
    Left _ -> Left "invalid token"
    Right _ -> Right ()
