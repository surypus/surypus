-- | Conversion (Phase 1: stubs + required implementations)
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}

module DAL.Conversion
  ( keyToInt
  , personFromEntity
  , goodsFromEntity
  , paymentFromEntity
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import Database.Persist.Sql (Key, fromSqlKey, Entity(..), SqlBackend)
import Database.Persist.Class.PersistEntity (PersistEntity, PersistEntityBackend)
import Database.Persist.Class.PersistStore (ToBackendKey)
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)
import Control.Monad.IO.Class (liftIO)
import DAL.Types (Payment(..), Person(..), Goods(..), QueryResult(..))
import qualified Surypus.DB.Schema as DBS

-- | Convert key to Int64 (polymorphic)
keyToInt :: (PersistEntity a, PersistEntityBackend a ~ SqlBackend, ToBackendKey SqlBackend a) => Key a -> Int64
keyToInt = fromSqlKey

-- | Convert entity to value (stub)
personFromEntity :: a -> Maybe Person
personFromEntity _ = Nothing

-- | Convert entity to value (stub)
goodsFromEntity :: a -> Maybe Goods
goodsFromEntity _ = Nothing

-- | Convert PaymentEntity to Payment using field selectors
paymentFromEntity :: Entity DBS.PaymentEntity -> Payment
paymentFromEntity (Entity k e) = Payment
  { paymentId = fromSqlKey k
  , paymentBillId = DBS.paymentEntityBillId e
  , paymentAmount = DBS.paymentEntityAmount e
  , paymentDate = DBS.paymentEntityDate e
  , paymentMethod = DBS.paymentEntityMethod e
  }