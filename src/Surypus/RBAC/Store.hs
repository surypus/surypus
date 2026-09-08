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
data RBACStore = RBACStore (IORef StoreData)

data StoreData = StoreData
  { sdRoles :: [DynamicRole],
    sdGrants :: [PermissionGrant],
    sdAudit :: [AuditEntry]
  }

-- | Create a new RBAC store
newRBACStore :: (AuditEntry -> IO ()) -> IO RBACStore
newRBACStore _auditCallback = do
  ref <- newIORef StoreData {sdRoles = [], sdGrants = [], sdAudit = []}
  pure $ RBACStore ref

-- | List all roles
listRoles :: RBACStore -> IO [DynamicRole]
listRoles (RBACStore ref) = readIORef ref >>= pure . sdRoles

-- | List all grants
listGrants :: RBACStore -> IO [PermissionGrant]
listGrants (RBACStore ref) = readIORef ref >>= pure . sdGrants

-- | List audit entries
listAuditEntries :: RBACStore -> IO [AuditEntry]
listAuditEntries (RBACStore ref) = readIORef ref >>= pure . sdAudit

-- | Write an audit entry
writeAuditEntry :: RBACStore -> AuditEntry -> IO ()
writeAuditEntry (RBACStore ref) entry =
  modifyIORef' ref $ \s ->
    s {sdAudit = entry : sdAudit s}

-- | Add a permission grant
addGrant :: RBACStore -> PermissionGrant -> IO ()
addGrant (RBACStore ref) grant =
  modifyIORef' ref $ \s ->
    s {sdGrants = grant : sdGrants s}

-- | Remove a permission grant
removeGrant :: RBACStore -> Text -> Text -> PermissionGrant -> IO ()
removeGrant (RBACStore ref) _from _to _grant =
  modifyIORef' ref $ \s ->
    s {sdGrants = filter (not . matchesGrant) (sdGrants s)}
  where
    matchesGrant g = pgFrom g == _from && pgTo g == _to

-- | Upsert a role
upsertRole :: RBACStore -> DynamicRole -> IO ()
upsertRole (RBACStore ref) role' = do
  modifyIORef' ref $ \s ->
    s
      { sdRoles =
          filter (\r -> drName r /= drName role') (sdRoles s)
            ++ [role']
      }

-- | Delete a role
deleteRole :: RBACStore -> Text -> IO ()
deleteRole (RBACStore ref) name =
  modifyIORef' ref $ \s ->
    s {sdRoles = filter (\r -> drName r /= name) (sdRoles s)}

-- | List active grants for a principal
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

-- | Cleanup expired grants
cleanupExpiredGrants :: RBACStore -> UTCTime -> IO Int
cleanupExpiredGrants (RBACStore ref) now = do
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

-- | Cleanup audit entries (keep latest N)
cleanupAuditEntries :: RBACStore -> Maybe Int64 -> IO Int
cleanupAuditEntries (RBACStore ref) mKeep = do
  s <- readIORef ref
  let audit = sdAudit s
      limit = fromIntegral $ maybe 1000 fromIntegral mKeep
      (keep, removed) = splitAt limit audit
  modifyIORef' ref $ \s' -> s' {sdAudit = keep}
  pure $ length removed