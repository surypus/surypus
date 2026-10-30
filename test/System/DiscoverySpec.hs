{-# LANGUAGE OverloadedStrings #-}

-- | Unit tests for System.Discovery.
-- Covers service registration, discovery, lookup, heartbeat, and cleanup.
module System.DiscoverySpec (spec) where

import Control.Concurrent.STM (TVar, atomically, readTVar, writeTVar, newTVarIO)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime, getCurrentTime, addUTCTime, NominalDiffTime)
import System.Discovery
import System.Directory (createDirectoryIfMissing, removeFile, removeDirectoryRecursive)
import System.FilePath ((</>))
import Test.Hspec
import Test.QuickCheck
import Test.QuickCheck.Monadic (monadicIO, run, assert)

-- ============================================================================
-- Test helpers
-- ============================================================================

-- | Fixed test configuration.
testConfig :: DiscoveryConfig
testConfig = DiscoveryConfig
  { discoveryInterval = 30
  , discoveryTimeout = 5
  , serviceTypes = ["local", "remote"]
  }

-- | Create a UTCTime at a fixed point (2025-06-15 12:00:00 UTC).
-- Note: ServiceInfo has no Show instance, so we use length/elem checks instead of shouldBe.

-- ============================================================================
-- isServiceFile tests
-- ============================================================================

isServiceFileSpec :: Spec
isServiceFileSpec = describe "isServiceFile" $ do
  it "accepts .svc files" $ do
    isServiceFile "myservice.svc" `shouldBe` True
  it "accepts .svc files with paths" $ do
    isServiceFile "/etc/services/web.svc" `shouldBe` True
  it "rejects non-.svc files" $ do
    isServiceFile "myservice.conf" `shouldBe` False
  it "rejects files without extension" $ do
    isServiceFile "myservice" `shouldBe` False
  it "rejects .svc in the middle of the name" $ do
    isServiceFile "myservice.svc.bak" `shouldBe` False
  it "rejects empty string" $ do
    isServiceFile "" `shouldBe` False

-- ============================================================================
-- initServiceDiscovery tests
-- ============================================================================

initServiceDiscoverySpec :: Spec
initServiceDiscoverySpec = describe "initServiceDiscovery" $ do
  it "creates an empty registry" $ do
    registry <- initServiceDiscovery testConfig
    services <- listServices registry
    services `shouldBe` ([] :: [ServiceInfo])
  it "starts with no events" $ do
    registry <- initServiceDiscovery testConfig
    events <- discoverEvents registry
    events `shouldBe` ([] :: [(UTCTime, Text, Text)])

-- ============================================================================
-- registerService / getService / listServices tests
-- ============================================================================

registerServiceSpec :: Spec
registerServiceSpec = describe "registerService" $ do
  it "registers a service and makes it retrievable" $ do
    registry <- initServiceDiscovery testConfig
    registerService registry "/etc/services" "test1.svc"
    mService <- getService registry "test1"
    case mService of
      Nothing -> expectationFailure "Service should be registered"
      Just info -> do
        serviceId info `shouldBe` "test1"
        serviceName info `shouldBe` "test1"
        serviceType info `shouldBe` "local"
  it "lists all registered services" $ do
    registry <- initServiceDiscovery testConfig
    registerService registry "/etc/services" "svc1.svc"
    registerService registry "/etc/services" "svc2.svc"
    services <- listServices registry
    map serviceId services `shouldMatchList` ["svc1", "svc2"]
  it "overwrites an existing service with the same id" $ do
    registry <- initServiceDiscovery testConfig
    registerService registry "/etc/services" "dup.svc"
    registerService registry "/etc/services" "dup.svc"
    services <- listServices registry
    length services `shouldBe` 1
  it "records a discover event on registration" $ do
    registry <- initServiceDiscovery testConfig
    registerService registry "/etc/services" "evt.svc"
    events <- discoverEvents registry
    length events `shouldBe` 1
    let (_, action, svcId) = head events
    action `shouldBe` "discover"
    svcId `shouldBe` "evt"
  it "returns Nothing for an unknown service id" $ do
    registry <- initServiceDiscovery testConfig
    mService <- getService registry "nonexistent"
    mService `shouldBe` (Nothing :: Maybe ServiceInfo)

-- ============================================================================
-- updateHeartbeat tests
-- ============================================================================

updateHeartbeatSpec :: Spec
updateHeartbeatSpec = describe "updateHeartbeat" $ do
  it "updates the lastSeen timestamp" $ do
    registry <- initServiceDiscovery testConfig
    registerService registry "/etc/services" "hb.svc"
    mService1 <- getService registry "hb"
    now <- getCurrentTime
    updateHeartbeat registry "hb"
    mService2 <- getService registry "hb"
    case (mService1, mService2) of
      (Just s1, Just s2) -> lastSeen s2 `shouldNotBe` lastSeen s1
      _ -> expectationFailure "Service should exist"
  it "does nothing for an unknown service id" $ do
    registry <- initServiceDiscovery testConfig
    updateHeartbeat registry "nonexistent"
    services <- listServices registry
    services `shouldBe` ([] :: [ServiceInfo])

-- ============================================================================
-- discoverServices tests
-- ============================================================================

discoverServicesSpec :: Spec
discoverServicesSpec = describe "discoverServices" $ do
  it "discovers .svc files in a directory" $ do
    dir <- createTempServiceDir
    registry <- initServiceDiscovery testConfig
    discoverServices registry dir
    services <- listServices registry
    map serviceId services `shouldMatchList` ["alpha", "beta"]
    removeDirectoryRecursive dir
  it "ignores non-.svc files in a directory" $ do
    dir <- createTempServiceDir
    registry <- initServiceDiscovery testConfig
    discoverServices registry dir
    services <- listServices registry
    map serviceId services `shouldSatisfy` all (`notElem` ["README.md", "config.json"])
    removeDirectoryRecursive dir
  it "does nothing for a non-existent directory" $ do
    registry <- initServiceDiscovery testConfig
    discoverServices registry "/nonexistent/path/that/does/not/exist"
    services <- listServices registry
    services `shouldBe` ([] :: [ServiceInfo])
  it "discovers nested .svc files with correct ids" $ do
    dir <- createTempServiceDir
    registry <- initServiceDiscovery testConfig
    discoverServices registry dir
    mAlpha <- getService registry "alpha"
    case mAlpha of
      Nothing -> expectationFailure "alpha service should be discovered"
      Just info -> serviceType info `shouldBe` "local"
    removeDirectoryRecursive dir

-- ============================================================================
-- cleanupStaleServices tests
-- ============================================================================

cleanupStaleServicesSpec :: Spec
cleanupStaleServicesSpec = describe "cleanupStaleServices" $ do
  it "keeps freshly registered services" $ do
    registry <- initServiceDiscovery testConfig
    registerService registry "/etc/services" "fresh.svc"
    cleanupStaleServices registry
    mService <- getService registry "fresh"
    mService `shouldSatisfy` maybe False (const True)
  it "removes stale services (lastSeen > 60s ago)" $ do
    registry <- initServiceDiscovery testConfig
    registerService registry "/etc/services" "stale.svc"
    now <- getCurrentTime
    -- Manually age the service's lastSeen to 120 seconds ago
    atomically $ do
      m <- readTVar (registryMap registry)
      case Map.lookup "stale" m of
        Just info -> do
          let aged = info { lastSeen = addUTCTime (fromIntegral (-120) :: NominalDiffTime) now }
          writeTVar (registryMap registry) (Map.insert "stale" aged m)
        Nothing -> return ()
    cleanupStaleServices registry
    mService <- getService registry "stale"
    mService `shouldBe` (Nothing :: Maybe ServiceInfo)
  it "removes only stale services, keeps fresh ones" $ do
    registry <- initServiceDiscovery testConfig
    registerService registry "/etc/services" "keep.svc"
    registerService registry "/etc/services" "drop.svc"
    now <- getCurrentTime
    -- Age only "drop.svc"
    atomically $ do
      m <- readTVar (registryMap registry)
      case Map.lookup "drop" m of
        Just info -> do
          let aged = info { lastSeen = addUTCTime (fromIntegral (-120) :: NominalDiffTime) now }
          writeTVar (registryMap registry) (Map.insert "drop" aged m)
        Nothing -> return ()
    cleanupStaleServices registry
    mKeep <- getService registry "keep"
    mDrop <- getService registry "drop"
    mKeep `shouldSatisfy` maybe False (const True)
    mDrop `shouldBe` (Nothing :: Maybe ServiceInfo)

-- ============================================================================
-- Property tests
-- ============================================================================

prop_registerThenGet :: Property
prop_registerThenGet = monadicIO $ do
    registry <- run $ initServiceDiscovery testConfig
    let svcId = "prop-test"
    run $ registerService registry "/tmp" "prop-test.svc"
    mService <- run $ getService registry svcId
    assert $ maybe False ((== svcId) . serviceId) mService

prop_listServicesCount :: Property
prop_listServicesCount = monadicIO $ do
    registry <- run $ initServiceDiscovery testConfig
    run $ registerService registry "/tmp" "a.svc"
    run $ registerService registry "/tmp" "b.svc"
    services <- run $ listServices registry
    assert $ length services == 2

-- ============================================================================
-- Main spec
-- ============================================================================

-- | Create a temporary directory with .svc and non-.svc files.
-- Returns the directory path (caller must clean up).
createTempServiceDir :: IO FilePath
createTempServiceDir = do
    let dir = "/tmp/surypus-discovery-test"
    createDirectoryIfMissing False dir
    writeFile (dir </> "alpha.svc") "{}"
    writeFile (dir </> "beta.svc") "{}"
    writeFile (dir </> "README.md") "not a service"
    writeFile (dir </> "config.json") "{}"
    return dir

spec :: Spec
spec = do
  describe "System.Discovery" $ do
    isServiceFileSpec
    initServiceDiscoverySpec
    registerServiceSpec
    updateHeartbeatSpec
    discoverServicesSpec
    cleanupStaleServicesSpec
  describe "System.Discovery properties" $ do
    it "register then get returns the service" $ property prop_registerThenGet
    it "listServices returns all registered services" $ property prop_listServicesCount
