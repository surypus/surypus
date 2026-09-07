{-# LANGUAGE OverloadedStrings #-}
module Surypus.API.MetricsMiddleware
  ( MetricsMiddlewareConfig   (..),
    withMetricsCollection,
  )
where

import Control.Monad (when)
import Data.Text (Text)
import Network.HTTP.Types (statusCode)
import Network.Wai (Application, responseStatus)
import Surypus.Metrics (Metrics, recordCounter, recordTimer)
import Data.Time.Clock (UTCTime, getCurrentTime, diffUTCTime)

data MetricsMiddlewareConfig = MetricsMiddlewareConfig
  { mmcMetrics :: Metrics,
    mmcPublicPaths :: [Text]
  }

withMetricsCollection :: MetricsMiddlewareConfig -> Application -> Application
withMetricsCollection cfg app req respond = do
  start <- getCurrentTime
  recordCounter (mmcMetrics cfg) "http.requests_total" 1
  app req $ \res -> do
    let sc = statusCode (responseStatus res)
    when (sc >= 500) $
      recordCounter (mmcMetrics cfg) "http.requests_error" 1
    end <- getCurrentTime
    let elapsedSec = realToFrac (diffUTCTime end start)
    recordTimer (mmcMetrics cfg) "http.request_duration" elapsedSec
    respond res
