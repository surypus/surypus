{-# LANGUAGE OverloadedStrings #-}

-- | Orphan PersistField instances for Data.UUID (persistent lacks them out of the box).
module DAL.UUIDOrphans () where

import qualified Data.Text as T
import Data.UUID (UUID)
import qualified Data.UUID as UUID
import Database.Persist
import Database.Persist.Sql

instance PersistField UUID where
  toPersistValue = PersistText . UUID.toText
  fromPersistValue (PersistText t) =
    maybe (Left $ T.pack ("UUID: invalid textual value: " ++ T.unpack t)) Right (UUID.fromText t)
  fromPersistValue (PersistByteString bs) =
    maybe (Left (T.pack "UUID: invalid byte value")) Right (UUID.fromASCIIBytes bs)
  fromPersistValue v =
    Left (T.pack ("UUID: unexpected persist value: " ++ show v))

instance PersistFieldSql UUID where
  sqlType _ = SqlOther "uuid"
