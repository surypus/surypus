module System.LoadBalancer where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar, atomically, readTVarIO)
import Data.Function (on)
import Data.List (minimumBy)
import qualified Data.List as L
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T


-- | Load balancer configuration
data LoadBalancerConfig = LoadBalancerConfig
  { lbAlgorithm :: LoadBalancingAlgorithm,
    lbMaxConnections :: Int,
    lbHealthCheckInterval :: Int
  }

-- | Load balancing algorithms
data LoadBalancingAlgorithm
  = RoundRobin
  | LeastConnections
  | IPHash
  | WeightedRoundRobin
  deriving (Show, Eq)

-- | Server definition
data Server = Server
  { serverId :: Text,
    serverAddress :: Text,
    serverWeight :: Int,
    serverActive :: Bool,
    serverCurrentConnections :: TVar Int
  }

-- | Load balancer state
data LoadBalancer = LoadBalancer
  { lbConfig :: LoadBalancerConfig,
    lbServers :: TVar [Server],
    lbCurrentIndex :: TVar Int,
    lbClientMappings :: TVar (Map.Map Text Text)
  }

-- | Initialize load balancer
initLoadBalancer :: LoadBalancerConfig -> IO LoadBalancer
initLoadBalancer config = do
  serversVar <- newTVarIO []
  indexVar <- newTVarIO 0
  mappingsVar <- newTVarIO Map.empty
  return $ LoadBalancer config serversVar indexVar mappingsVar

-- | Add server to load balancer
addServer :: LoadBalancer -> Server -> IO ()
addServer lb server = atomically $ do
  servers <- readTVar (lbServers lb)
  writeTVar (lbServers lb) (servers ++ [server])

-- | Remove server from load balancer
removeServer :: LoadBalancer -> Text -> IO ()
removeServer lb sid = atomically $ do
  servers <- readTVar (lbServers lb)
  let filtered = filter (\s -> sid /= serverId s) servers
  writeTVar (lbServers lb) filtered

-- | Get next server based on algorithm
getNextServer :: LoadBalancer -> Text -> IO (Maybe Server)
getNextServer lb clientIp = do
  servers <- readTVarIO (lbServers lb)
  let activeServers = filter serverActive servers
  if null activeServers
    then return Nothing
    else case lbAlgorithm (lbConfig lb) of
      RoundRobin -> do
        idx <- readTVarIO (lbCurrentIndex lb)
        let nextIdx = (idx + 1) `mod` length activeServers
        atomically $ writeTVar (lbCurrentIndex lb) nextIdx
        return $ Just (activeServers !! nextIdx)
      LeastConnections -> do
        conns <- mapM (readTVarIO . serverCurrentConnections) activeServers
        let zipped = zip activeServers conns
            minServer = minimumBy (compare `on` snd) zipped
        return $ Just (fst minServer)
      IPHash -> do
        -- Hash client IP and use modulo to select server
        let hashVal = hashClientIP clientIp
            idx = hashVal `mod` length activeServers
        return $ Just (activeServers !! idx)
      WeightedRoundRobin -> do
        -- Select server based on weight
        case selectByWeight activeServers of
          Nothing -> return Nothing
          Just server -> return (Just server)

-- | Handle client request
handleRequest :: LoadBalancer -> Text -> IO (Maybe Server)
handleRequest lb clientIp = do
  mServer <- getNextServer lb clientIp
  case mServer of
    Just server -> do
      -- Increment connection count
      atomically $ do
        conn <- readTVar (serverCurrentConnections server)
        writeTVar (serverCurrentConnections server) (conn + 1)
      -- Map client to server (sticky sessions)
      atomically $ do
        mappings <- readTVar (lbClientMappings lb)
        let updated = Map.insert clientIp (serverId server) mappings
        writeTVar (lbClientMappings lb) updated
      return mServer
    Nothing -> return Nothing

-- | Health check server
healthCheckServer :: Server -> IO Bool
healthCheckServer server = do
  -- Simulate health check
  return True

-- | Run health checks
runHealthChecks :: LoadBalancer -> IO ()
runHealthChecks lb = do
  servers <- readTVarIO (lbServers lb)
  mapM_
    ( \s -> do
        healthy <- healthCheckServer s
        atomically $ do
          -- Update server active status
          writeTVar (serverCurrentConnections s) 0
        return ()
    )
    servers

-- | Get server statistics
getServerStats :: LoadBalancer -> IO [(Text, Int)]
getServerStats lb = do
  servers <- readTVarIO (lbServers lb)
  conns <- mapM (readTVarIO . serverCurrentConnections) servers
  return $ zip (map serverId servers) conns

-- | Hash client IP for IPHash algorithm
hashClientIP :: Text -> Int
hashClientIP ip =
  case T.uncons ip of
    Nothing -> 0  -- Empty IP defaults to 0
    Just (_, rest) -> fromEnum (T.last rest) `mod` 1000

-- | Select server by weight (returns Nothing if no servers)
selectByWeight :: [Server] -> Maybe Server
selectByWeight servers =
  case servers of
    [] -> Nothing
    (s:_) ->
      case filter ((> 0) . serverWeight) servers of
        [] -> Just s  -- All servers have zero weight, return first server
        weighted ->
          let totalWeight = sum (map serverWeight weighted)
              target = if totalWeight > 0 then totalWeight `div` 2 else 0
              (acc, _) = L.foldl' (\ (srv, curr) svr ->
                if curr >= target || serverWeight svr <= 0
                  then (srv, curr)
                  else (svr, curr + serverWeight svr))
                (head weighted, 0) weighted
          in Just acc
