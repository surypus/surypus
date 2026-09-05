{-# LANGUAGE OverloadedStrings #-}
module System.Discovery where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar, atomically, readTVarIO)
import Control.Monad (when)
import Data.Function (on)
import Data.Monoid ((<>))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime, getCurrentTime, diffUTCTime)
import System.Directory (doesDirectoryExist, getDirectoryContents)
import System.FilePath (takeExtension, dropExtension, (</>))

-- | Service discovery configuration
data DiscoveryConfig = DiscoveryConfig
  { discoveryInterval :: Int,
    discoveryTimeout :: Int,
    serviceTypes :: [Text]
  }

-- | Discovered service
data ServiceInfo = ServiceInfo
  { serviceId :: Text,
    serviceName :: Text,
    serviceType :: Text,
    serviceUrl :: Text,
    serviceMetadata :: Map.Map Text Text,
    lastSeen :: UTCTime
  }

-- | Service registry
data ServiceRegistry = ServiceRegistry
  { registryMap :: TVar (Map.Map Text ServiceInfo),
    registryConfig :: DiscoveryConfig,
    registryEvents :: TVar [(UTCTime, Text, Text)]
  }

-- | Initialize service discovery
initServiceDiscovery :: DiscoveryConfig -> IO ServiceRegistry
initServiceDiscovery config = do
  mapVar <- newTVarIO Map.empty
  eventsVar <- newTVarIO []
  return $ ServiceRegistry mapVar config eventsVar

-- | Discover services in directory
discoverServices :: ServiceRegistry -> FilePath -> IO ()
discoverServices registry path = do
  exists <- doesDirectoryExist path
  when exists $ do
    contents <- getDirectoryContents path
    let services = filter (isServiceFile) contents
    mapM_ (registerService registry path) services

-- | Check if file is a service definition
isServiceFile :: FilePath -> Bool
isServiceFile name = takeExtension name == ".svc"

-- | Register a discovered service
registerService :: ServiceRegistry -> FilePath -> FilePath -> IO ()
registerService registry basePath file = do
  now <- getCurrentTime
  let serviceIdStr = dropExtension file
      serviceIdText = T.pack serviceIdStr
      info =
        ServiceInfo
          { serviceId = serviceIdText,
            serviceName = serviceIdText,
            serviceType = "local",
            serviceUrl = "file://" <> T.pack basePath <> "/" <> T.pack file,
            serviceMetadata = Map.empty,
            lastSeen = now
          }
  atomically $ do
    m <- readTVar (registryMap registry)
    writeTVar (registryMap registry) (Map.insert serviceIdText info m)
    events <- readTVar (registryEvents registry)
    writeTVar (registryEvents registry) ((now, "discover", serviceIdText) : events)

-- | Get service by ID
getService :: ServiceRegistry -> Text -> IO (Maybe ServiceInfo)
getService registry sid = do
  m <- readTVarIO (registryMap registry)
  return $ Map.lookup sid m

-- | List all services
listServices :: ServiceRegistry -> IO [ServiceInfo]
listServices registry = do
  m <- readTVarIO (registryMap registry)
  return $ Map.elems m

-- | Update service heartbeat
updateHeartbeat :: ServiceRegistry -> Text -> IO ()
updateHeartbeat registry sid = do
  now <- getCurrentTime
  atomically $ do
    m <- readTVar (registryMap registry)
    case Map.lookup sid m of
      Just info -> do
        let updated = info {lastSeen = now}
        writeTVar (registryMap registry) (Map.insert sid updated m)
      Nothing -> return ()

-- | Remove stale services
cleanupStaleServices :: ServiceRegistry -> IO ()
cleanupStaleServices registry = do
  now <- getCurrentTime
  atomically $ do
    m <- readTVar (registryMap registry)
    let valid = Map.filter (\info -> diffUTCTime now (lastSeen info) < 60) m
    writeTVar (registryMap registry) valid

-- | Subscribe to discovery events
discoverEvents :: ServiceRegistry -> IO [(UTCTime, Text, Text)]
discoverEvents registry = do
  readTVarIO (registryEvents registry)
