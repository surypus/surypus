-- | Error types for the application
module Surypus.Error
  ( AppError   (..),
    AppErrorType   (..),
  )
where

import Data.Text (Text)

-- | Application error types
data AppErrorType
  = ValidationError
  | NotFoundError
  | ForbiddenError
  | ConflictError
  | DatabaseError
  | InternalError
  | AuthenticationError
  | AuthorizationError
  deriving (Show, Eq)

-- | Application error
data AppError = AppError
  { aeType :: AppErrorType,
    aeMessage :: Text,
    aeDetails :: Maybe Text
  }
  deriving (Show, Eq)