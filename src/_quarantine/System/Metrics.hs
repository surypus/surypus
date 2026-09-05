module System.Metrics
  ( Metrics   (..),
    initMetrics,
    incrementRequests,
    incrementResponses4xx,
    incrementResponses5xx,
    getMetrics,
    MetricsState
  ) where

import Control.Concurrent.STM (TVar, atomically, modifyTVar, newTVarIO, readTVarIO)
import Data.Int (Int64)

data Metrics = Metrics
  { requestsTotal :: TVar Int64,
    responses4xx :: TVar Int64,
    responses5xx :: TVar Int64
  }

type MetricsState = Metrics

initMetrics :: IO Metrics
initMetrics = do
  reqs <- newTVarIO 0
  r4xx <- newTVarIO 0
  r5xx <- newTVarIO 0
  pure $ Metrics reqs r4xx r5xx

incrementRequests :: Metrics -> IO ()
incrementRequests m = do
  atomically $ do
    modifyTVar (requestsTotal m) (+ 1)

incrementResponses4xx :: Metrics -> IO ()
incrementResponses4xx m = do
  atomically $ do
    modifyTVar (responses4xx m) (+ 1)

incrementResponses5xx :: Metrics -> IO ()
incrementResponses5xx m = do
  atomically $ do
    modifyTVar (responses5xx m) (+ 1)

getMetrics :: Metrics -> IO (Int64, Int64, Int64)
getMetrics m = do
  reqs <- readTVarIO (requestsTotal m)
  r4xx <- readTVarIO (responses4xx m)
  r5xx <- readTVarIO (responses5xx m)
  pure (reqs, r4xx, r5xx)
