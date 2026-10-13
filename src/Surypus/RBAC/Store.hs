-- | RBAC Store - Persistent storage for RBAC data
module Surypus.RBAC.Store
  ( RBACStore,
    newRBACStore,
    listRoles,
    listGrants,
    writeAuditEntry,
    addGrant,
    removeGrant,
    cleanupExpiredGrants,
    activeDelegations,
    listAuditEntries,
    cleanupAuditEntries,
    DynamicRole   (..),
    ScopedPermission   (..),
    PermissionGrant   (..),
    PermissionScope   (..),
    AuditEntry   (..),
    upsertRole,
    deleteRole,
  )
where

import Data.Int (Int64)
import Data.IORef (IORef, newIORef, readIORef, modifyIORef')
import Data.Text (Text)
import Data.Time (UTCTime)

-- | Permission scope
data PermissionScope
  = GlobalScope
  | ResourceScope Text
  deriving (Show, Eq)

-- | Scoped permission
data ScopedPermission = ScopedPermission
  { spPermission :: Text,
    spScope :: PermissionScope
  }
  deriving (Show, Eq)

-- | Dynamic role
data DynamicRole = DynamicRole
  { drName :: Text,
    drPermissions :: [ScopedPermission]
  }
  deriving (Show, Eq)

-- | Permission grant (delegation)
data PermissionGrant = PermissionGrant
  { pgFrom :: Text,
    pgTo :: Text,
    pgPermission :: ScopedPermission,
    pgExpiresAt :: Maybe UTCTime
  }
  deriving (Show, Eq)

-- | Audit entry
data AuditEntry = AuditEntry
  { aeTimestamp :: UTCTime,
    aePrincipal :: Text,
    aeRole :: Text,
    aePermission :: Text,
    aeResource :: Maybe Text,
    aeAllowed :: Bool,
    aeReason :: Text
  }
  deriving (Show, Eq)

-- | RBAC Store
--
-- Carries the audit sink passed to 'newRBACStore' so that
-- 'writeAuditEntry' can push every entry both into the in-memory log
-- and to the external sink (logger / DB).
data RBACStore = RBACStore (IORef StoreData) (Maybe (AuditEntry -> IO ()))

data StoreData = StoreData
  { sdRoles :: [DynamicRole],
    sdGrants :: [PermissionGrant],
    sdAudit :: [AuditEntry]
  }

-- | Create a new RBAC store.
--
-- The audit callback is invoked synchronously by 'writeAuditEntry'
-- for every recorded entry, after the entry is appended to the log.
newRBACStore :: (AuditEntry -> IO ()) -> IO RBACStore
newRBACStore auditCallback = do
  ref <- newIORef StoreData {sdRoles = [], sdGrants = [], sdAudit = []}
  pure $ RBACStore ref (Just auditCallback)

-- | List all roles
listRoles :: RBACStore -> IO [DynamicRole]
listRoles (RBACStore ref _) = readIORef ref >>= pure . sdRoles

-- | List all grants
listGrants :: RBACStore -> IO [PermissionGrant]
listGrants (RBACStore ref _) = readIORef ref >>= pure . sdGrants

-- | List audit entries (newest first)
listAuditEntries :: RBACStore -> IO [AuditEntry]
listAuditEntries (RBACStore ref _) = readIORef ref >>= pure . sdAudit

-- | Write an audit entry: append to the in-memory log (newest first)
-- and forward it to the store's audit sink.
writeAuditEntry :: RBACStore -> AuditEntry -> IO ()
writeAuditEntry (RBACStore ref mAuditCallback) entry = do
  modifyIORef' ref $ \s ->
    s {sdAudit = entry : sdAudit s}
  case mAuditCallback of
    Just cb -> cb entry
    Nothing -> pure ()

-- | Add a permission grant (prepended, so the newest grant is first)
addGrant :: RBACStore -> PermissionGrant -> IO ()
addGrant (RBACStore ref _) grant =
  modifyIORef' ref $ \s ->
    s {sdGrants = grant : sdGrants s}

-- | Remove a permission grant.
--
-- Revokes exactly the passed grant: a stored grant survives unless its
-- principal pair matches 'from'\/'to' AND it equals 'grant' (same
-- permission, scope and expiry). Revoking one grant of a pair must not
-- silently revoke the other grants between the same principals.
removeGrant :: RBACStore -> Text -> Text -> PermissionGrant -> IO ()
removeGrant (RBACStore ref _) from to grant =
  modifyIORef' ref $ \s ->
    s {sdGrants = filter (not . matchesGrant) (sdGrants s)}
  where
    matchesGrant g = pgFrom g == from && pgTo g == to && g == grant

-- | Upsert a role: a role with the same name is replaced (no duplicates)
upsertRole :: RBACStore -> DynamicRole -> IO ()
upsertRole (RBACStore ref _) role' =
  modifyIORef' ref $ \s ->
    s
      { sdRoles =
          filter (\r -> drName r /= drName role') (sdRoles s)
            ++ [role']
      }

-- | Delete a role
deleteRole :: RBACStore -> Text -> IO ()
deleteRole (RBACStore ref _) name =
  modifyIORef' ref $ \s ->
    s {sdRoles = filter (\r -> drName r /= name) (sdRoles s)}

-- | List active grants for a principal.
--
-- 'Nothing' means "no principal filter": every active grant is
-- returned. A grant is active when it has no expiry or its expiry is
-- at or after 'now'.
activeDelegations :: RBACStore -> Maybe Text -> UTCTime -> IO [PermissionGrant]
activeDelegations store mPrincipal now = do
  grants <- listGrants store
  pure $
    filter
      ( \g ->
          maybe True (\p -> pgFrom g == p || pgTo g == p) mPrincipal
            && isActive g now
      )
      grants
  where
    isActive g t = maybe True (>= t) (pgExpiresAt g)

-- | Cleanup expired grants.
--
-- A grant expiring exactly at 'now' is still active and is kept
-- (same boundary as 'activeDelegations'). Returns the number removed.
cleanupExpiredGrants :: RBACStore -> UTCTime -> IO Int
cleanupExpiredGrants (RBACStore ref _) now = do
  s <- readIORef ref
  let gs = sdGrants s
      (active, expired) = foldr splitGrants ([], []) gs
  modifyIORef' ref $ \s' -> s' {sdGrants = active}
  pure $ length expired
  where
    splitGrants g (act, expr) =
      if maybe True (>= now) (pgExpiresAt g)
        then (g : act, expr)
        else (act, g : expr)

-- | Cleanup audit entries (keep latest N, newest first).
-- Default keep limit is 1000 when 'mKeep' is 'Nothing'.
-- Returns the number removed.
cleanupAuditEntries :: RBACStore -> Maybe Int64 -> IO Int
cleanupAuditEntries (RBACStore ref _) mKeep = do
  s <- readIORef ref
  let audit = sdAudit s
      limit = fromIntegral $ maybe 1000 fromIntegral mKeep
      (keep, removed) = splitAt limit audit
  modifyIORef' ref $ \s' -> s' {sdAudit = keep}
  pure $ length removed
