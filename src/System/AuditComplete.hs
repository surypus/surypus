module System.AuditComplete where

import Control.Concurrent.STM (TVar, STM, newTVarIO, readTVar, writeTVar, atomically, readTVarIO)
import Control.Monad (when)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.ByteString.Lazy as BL
import Data.Time.Clock (UTCTime, getCurrentTime, addUTCTime)
import Data.Aeson (ToJSON(toJSON), encode, (.=))
import Data.Aeson.Types (object)
import Data.Aeson.Key (fromText)

-- | Audit severity levels with numeric values for filtering
data AuditSeverity
  = DebugS
  | InfoS
  | WarningS
  | ErrorS
  | CriticalS
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | Complete audit event with full context
data AuditEventComplete = AuditEventComplete
  { auditEventId :: Text,
    auditTimestamp :: UTCTime,
    auditSeverity :: AuditSeverity,
    auditSource :: Text,
    auditAction :: Text,
    auditEntity :: Text,
    auditEntityId :: Maybe Text,
    auditUserId :: Maybe Text,
    auditUsername :: Maybe Text,
    auditChanges :: Maybe BL.ByteString,
    auditMetadata :: [(Text, Text)],
    auditIpAddress :: Maybe Text,
    auditUserAgent :: Maybe Text,
    auditRequestPath :: Maybe Text,
    auditStatusCode :: Maybe Int
  } deriving (Show)

-- Stub ToJSON instance
instance ToJSON AuditEventComplete where
  toJSON _ = object [fromText (T.pack "stub") .= (T.pack "audit-event" :: Text)]

-- | Audit storage with compliance guarantees
data AuditStorage = AuditStorage
  { auditBuffer :: TVar [AuditEventComplete],
    auditIndex :: TVar (Map.Map Text [AuditEventComplete]),
    auditRetentionDays :: Int,
    auditComplianceMode :: Bool
  }

-- | Initialize complete audit system
initAuditComplete :: Int -> Bool -> IO AuditStorage
initAuditComplete retentionDays compliance = do
  bufferVar <- newTVarIO []
  indexVar <- newTVarIO Map.empty
  return $ AuditStorage
    { auditBuffer = bufferVar,
      auditIndex = indexVar,
      auditRetentionDays = retentionDays,
      auditComplianceMode = compliance
    }

-- | Write audit event with full compliance
writeAuditComplete :: AuditStorage -> AuditEventComplete -> IO ()
writeAuditComplete audit event = do
  -- Add to buffer
  atomically $ do
    buffer <- readTVar (auditBuffer audit)
    let newBuffer = event : take 10000 buffer  -- Keep last 10k events
    writeTVar (auditBuffer audit) newBuffer
    -- Update indices
    updateIndices audit event

  -- Enforce retention if in compliance mode (outside STM)
  when (auditComplianceMode audit) $ do
    now <- getCurrentTime
    let cutoff = addUTCTime (negate $ fromIntegral (auditRetentionDays audit * 24 * 3600)) now
    atomically $ do
      buffer' <- readTVar (auditBuffer audit)
      let valid = filter (\e -> auditTimestamp e > cutoff) buffer'
      writeTVar (auditBuffer audit) valid

-- | Update all indices
updateIndices :: AuditStorage -> AuditEventComplete -> STM ()
updateIndices audit event = do
  idx <- readTVar (auditIndex audit)
  let sourceKey = auditSource event
      updated = Map.insertWith (++) sourceKey [event] idx
  writeTVar (auditIndex audit) updated

-- | Query with complex filters
queryAuditComplete :: AuditStorage -> Maybe Text -> Maybe AuditSeverity -> Maybe UTCTime -> Maybe UTCTime -> IO [AuditEventComplete]
queryAuditComplete audit mSource mSeverity minTime maxTime = do
  idx <- readTVarIO (auditIndex audit)
  let candidates = case mSource of
        Nothing -> concat $ Map.elems idx
        Just src -> Map.findWithDefault [] src idx
  return $ filter (applyFilters mSeverity minTime maxTime) candidates

-- | Apply filter predicates
applyFilters :: Maybe AuditSeverity -> Maybe UTCTime -> Maybe UTCTime -> AuditEventComplete -> Bool
applyFilters mSeverity minTime maxTime event =
  let severityOk = case mSeverity of
        Nothing -> True
        Just s -> auditSeverity event >= s
      timeMinOk = case minTime of
        Nothing -> True
        Just t -> auditTimestamp event >= t
      timeMaxOk = case maxTime of
        Nothing -> True
        Just t -> auditTimestamp event <= t
  in severityOk && timeMinOk && timeMaxOk

-- | Export audit data in various formats
exportAuditData :: AuditStorage -> Text -> IO (Either Text BL.ByteString)
exportAuditData audit format = do
  events <- readTVarIO (auditBuffer audit)
  case format of
    f | f == T.pack "json" -> return $ Right $ encode events
    f | f == T.pack "compact" -> return $ Right $ BL.pack $ map (fromIntegral . fromEnum) $ show events
    _ -> return $ Left (T.pack "Unsupported format")

-- | Generate compliance report
generatComplianceReport audit = do
   events <- readTVarIO (auditBuffer audit)
   let report = T.unlines $
         [ T.pack "Compliance Report"
         , T.pack "Total Events: " <> T.pack (show (length events))
         , T.pack "Severity Breakdown: " <> T.pack (show $ countSeverities events)
         ]
   return report
   where
     countSeverities = Map.toList . foldr (\e m -> Map.insertWith (+) (auditSeverity e) 1 m) Map.empty

-- | Real-time audit streaming
streamAuditEvents :: AuditStorage -> (AuditEventComplete -> IO ()) -> IO ()
streamAuditEvents audit handler = do
  events <- readTVarIO (auditBuffer audit)
  mapM_ handler (reverse events)  -- Newest first
