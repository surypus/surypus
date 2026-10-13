{-# LANGUAGE OverloadedStrings #-}
module Surypus.RBAC.StoreSpec (spec) where

import Test.Hspec
import Data.IORef (newIORef, readIORef, modifyIORef')
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Surypus.RBAC.Store

-- | Fixed instant helper: t n = 2026-01-01 00:00:00 + n seconds
t :: Integer -> UTCTime
t n = UTCTime (fromGregorian 2026 1 1) (secondsToDiffTime n)

mkGrant :: Text -> Text -> Text -> Maybe UTCTime -> PermissionGrant
mkGrant from to perm expiry =
  PermissionGrant
    { pgFrom = from,
      pgTo = to,
      pgPermission = ScopedPermission perm GlobalScope,
      pgExpiresAt = expiry
    }

mkRole :: Text -> PermissionGrant -> DynamicRole
mkRole name grant = DynamicRole {drName = name, drPermissions = [pgPermission grant]}

mkAudit :: Text -> Bool -> AuditEntry
mkAudit principal allowed =
  AuditEntry
    { aeTimestamp = t 0,
      aePrincipal = principal,
      aeRole = "clerk",
      aePermission = "goods:read",
      aeResource = Nothing,
      aeAllowed = allowed,
      aeReason = "spec"
    }

quietStore :: IO RBACStore
quietStore = newRBACStore (const (pure ()))

spec :: Spec
spec = describe "Surypus.RBAC.Store" $ do
  describe "roles" $ do
    it "newRBACStore starts empty" $ do
      store <- quietStore
      roles <- listRoles store
      grants <- listGrants store
      audits <- listAuditEntries store
      roles `shouldBe` []
      grants `shouldBe` []
      audits `shouldBe` []

    it "upsertRole adds a role" $ do
      store <- quietStore
      let g = mkGrant "alice" "bob" "goods:read" Nothing
      upsertRole store (mkRole "clerk" g)
      listRoles store `shouldReturn` [mkRole "clerk" g]

    it "upsertRole replaces a role with the same name (no duplicates)" $ do
      store <- quietStore
      let g1 = mkGrant "alice" "bob" "goods:read" Nothing
          g2 = mkGrant "alice" "bob" "goods:write" Nothing
      upsertRole store (mkRole "clerk" g1)
      upsertRole store (mkRole "clerk" g2)
      upsertRole store (mkRole "manager" g1)
      roles <- listRoles store
      length (filter ((== "clerk") . drName) roles) `shouldBe` (1 :: Int)
      roles `shouldSatisfy` any ((== "goods:write") . spPermission . head . drPermissions)

    it "deleteRole removes a role by name" $ do
      store <- quietStore
      let g = mkGrant "alice" "bob" "goods:read" Nothing
      upsertRole store (mkRole "clerk" g)
      upsertRole store (mkRole "manager" g)
      deleteRole store "clerk"
      listRoles store `shouldReturn` [mkRole "manager" g]

    it "deleteRole of an unknown name is a no-op" $ do
      store <- quietStore
      let g = mkGrant "alice" "bob" "goods:read" Nothing
      upsertRole store (mkRole "clerk" g)
      deleteRole store "ghost"
      listRoles store `shouldReturn` [mkRole "clerk" g]

  describe "grants" $ do
    it "addGrant prepends the newest grant" $ do
      store <- quietStore
      let g1 = mkGrant "alice" "bob" "goods:read" Nothing
          g2 = mkGrant "carol" "dave" "goods:write" Nothing
      addGrant store g1
      addGrant store g2
      listGrants store `shouldReturn` [g2, g1]

    it "removeGrant revokes exactly the passed grant" $ do
      store <- quietStore
      let g1 = mkGrant "alice" "bob" "goods:read" Nothing
          g2 = mkGrant "alice" "bob" "goods:write" Nothing
      addGrant store g1
      addGrant store g2
      removeGrant store "alice" "bob" g1
      listGrants store `shouldReturn` [g2]

    it "removeGrant of a grant not in the store is a no-op" $ do
      store <- quietStore
      let g1 = mkGrant "alice" "bob" "goods:read" Nothing
          other = mkGrant "alice" "bob" "stock:read" Nothing
      addGrant store g1
      removeGrant store "alice" "bob" other
      listGrants store `shouldReturn` [g1]

    it "removeGrant leaves grants of other principal pairs untouched" $ do
      store <- quietStore
      let g1 = mkGrant "alice" "bob" "goods:read" Nothing
          g2 = mkGrant "carol" "dave" "goods:read" Nothing
      addGrant store g1
      addGrant store g2
      removeGrant store "alice" "bob" g1
      listGrants store `shouldReturn` [g2]

  describe "activeDelegations" $ do
    it "includes grants where the principal is the delegator" $ do
      store <- quietStore
      let g = mkGrant "alice" "bob" "goods:read" (Just (t 100))
      addGrant store g
      activeDelegations store (Just "alice") (t 0) `shouldReturn` [g]

    it "includes grants where the principal is the recipient" $ do
      store <- quietStore
      let g = mkGrant "alice" "bob" "goods:read" (Just (t 100))
      addGrant store g
      activeDelegations store (Just "bob") (t 0) `shouldReturn` [g]

    it "excludes grants the principal is not a party to" $ do
      store <- quietStore
      let g = mkGrant "alice" "bob" "goods:read" (Just (t 100))
      addGrant store g
      activeDelegations store (Just "carol") (t 0) `shouldReturn` []

    it "excludes grants expired before now" $ do
      store <- quietStore
      addGrant store (mkGrant "alice" "bob" "goods:read" (Just (t 50)))
      activeDelegations store (Just "alice") (t 100) `shouldReturn` []

    it "keeps grants expiring exactly at now (boundary is inclusive)" $ do
      store <- quietStore
      let g = mkGrant "alice" "bob" "goods:read" (Just (t 100))
      addGrant store g
      activeDelegations store (Just "alice") (t 100) `shouldReturn` [g]

    it "keeps grants with no expiry" $ do
      store <- quietStore
      let g = mkGrant "alice" "bob" "goods:read" Nothing
      addGrant store g
      activeDelegations store (Just "alice") (t 10) `shouldReturn` [g]

    it "Nothing principal returns every active grant" $ do
      store <- quietStore
      let g1 = mkGrant "alice" "bob" "goods:read" Nothing
          g2 = mkGrant "carol" "dave" "goods:write" (Just (t 100))
      addGrant store g1
      addGrant store g2
      activeDelegations store Nothing (t 0) `shouldReturn` [g2, g1]

    it "Nothing principal still excludes expired grants" $ do
      store <- quietStore
      addGrant store (mkGrant "alice" "bob" "goods:read" (Just (t 50)))
      addGrant store (mkGrant "carol" "dave" "goods:write" (Just (t 150)))
      activeDelegations store Nothing (t 100)
        `shouldReturn` [mkGrant "carol" "dave" "goods:write" (Just (t 150))]

  describe "cleanupExpiredGrants" $ do
    it "removes expired grants and returns the count" $ do
      store <- quietStore
      let g1 = mkGrant "alice" "bob" "goods:read" (Just (t 50))
          g2 = mkGrant "carol" "dave" "goods:write" (Just (t 200))
          g3 = mkGrant "erin" "frank" "stock:read" (Just (t 80))
      addGrant store g1
      addGrant store g2
      addGrant store g3
      removed <- cleanupExpiredGrants store (t 100)
      removed `shouldBe` (2 :: Int)
      listGrants store `shouldReturn` [g2]

    it "keeps grants expiring exactly at now" $ do
      store <- quietStore
      let g = mkGrant "alice" "bob" "goods:read" (Just (t 100))
      addGrant store g
      removed <- cleanupExpiredGrants store (t 100)
      removed `shouldBe` (0 :: Int)
      listGrants store `shouldReturn` [g]

    it "returns 0 and changes nothing when nothing is expired" $ do
      store <- quietStore
      let g = mkGrant "alice" "bob" "goods:read" Nothing
      addGrant store g
      removed <- cleanupExpiredGrants store (t 100)
      removed `shouldBe` (0 :: Int)
      listGrants store `shouldReturn` [g]

  describe "audit" $ do
    it "writeAuditEntry records entries newest-first" $ do
      store <- quietStore
      let e1 = mkAudit "alice" True
          e2 = mkAudit "bob" False
      writeAuditEntry store e1
      writeAuditEntry store e2
      listAuditEntries store `shouldReturn` [e2, e1]

    it "writeAuditEntry invokes the store's audit sink for every entry" $ do
      sink <- newIORef ([] :: [AuditEntry])
      store <- newRBACStore (\e -> modifyIORef' sink (++ [e]))
      let e1 = mkAudit "alice" True
          e2 = mkAudit "bob" False
      writeAuditEntry store e1
      writeAuditEntry store e2
      readIORef sink `shouldReturn` [e1, e2]

    it "cleanupAuditEntries keeps the latest N and returns the removed count" $ do
      store <- quietStore
      mapM_ (writeAuditEntry store) [mkAudit (T.pack (show n)) True | n <- [1 .. 5 :: Int]]
      removed <- cleanupAuditEntries store (Just 2)
      removed `shouldBe` (3 :: Int)
      entries <- listAuditEntries store
      length entries `shouldBe` (2 :: Int)
      map aePrincipal entries `shouldBe` ["5", "4"]

    it "cleanupAuditEntries default keeps 1000 latest entries" $ do
      store <- quietStore
      mapM_ (writeAuditEntry store) [mkAudit (T.pack (show n)) True | n <- [1 .. 1001 :: Int]]
      removed <- cleanupAuditEntries store Nothing
      removed `shouldBe` (1 :: Int)
      entries <- listAuditEntries store
      length entries `shouldBe` (1000 :: Int)
      aePrincipal (head entries) `shouldBe` "1001"
