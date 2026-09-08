-- | Transcendence - monad transformer for Surypus
module Transcendence (Transcendence, runTranscendence, returnT, bindT) where

import Control.Monad.IO.Class (MonadIO(..))
import Control.Monad.Trans.Class (MonadTrans(..))

-- | Transcendence monad transformer
newtype Transcendence m a = Transcendence { unTranscendence :: m a }

-- | Run Transcendence
runTranscendence :: Transcendence m a -> m a
runTranscendence = unTranscendence

-- | Lift inner monad
returnT :: Monad m => a -> Transcendence m a
returnT = Transcendence . return

-- | Bind Transcendence
bindT :: Monad m => Transcendence m a -> (a -> Transcendence m b) -> Transcendence m b
bindT m f = Transcendence $ do
  a <- unTranscendence m
  unTranscendence (f a)

instance Monad m => Functor (Transcendence m) where
  fmap f (Transcendence m) = Transcendence (fmap f m)

instance Monad m => Applicative (Transcendence m) where
  pure = Transcendence . pure
  (Transcendence f) <*> (Transcendence m) = Transcendence (f <*> m)

instance Monad m => Monad (Transcendence m) where
  return = pure
  (Transcendence m) >>= f = Transcendence (m >>= unTranscendence . f)

instance MonadTrans Transcendence where
  lift = Transcendence

instance MonadIO m => MonadIO (Transcendence m) where
  liftIO = Transcendence . liftIO
