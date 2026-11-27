{-# LANGUAGE OverloadedStrings #-}

-- | Tenant context must be request-scoped. A single global IORef allowed one
-- request to read another tenant's context under concurrent load.
module MultiTenancy.TenantContextSpec (spec) where

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Exception (SomeException, ioError, try)
import DAL.Database (clearCurrentTenantContext, currentTenantContext, withTenantContext)
import System.IO.Error (userError)
import Test.Hspec

spec :: Spec
spec = describe "tenant context isolation" $ do
  it "keeps two concurrent threads on separate tenant contexts" $ do
    clearCurrentTenantContext
    scoped <- newEmptyMVar
    resume <- newEmptyMVar
    finished <- newEmptyMVar
    resultA <- newEmptyMVar
    resultB <- newEmptyMVar
    _ <- forkIO $ withTenantContext 1 101 $ do
      putMVar scoped ()
      takeMVar resume
      currentTenantContext >>= putMVar resultA
      putMVar finished ()
    takeMVar scoped
    withTenantContext 2 202 $ do
      currentTenantContext >>= putMVar resultB
      putMVar resume ()
    a <- takeMVar resultA
    b <- takeMVar resultB
    a `shouldBe` Just (1, 101)
    b `shouldBe` Just (2, 202)

  it "clears the context after the scoped action" $ do
    clearCurrentTenantContext
    withTenantContext 3 303 (pure ())
    currentTenantContext `shouldReturn` Nothing

  it "restores an outer context after a nested scope" $ do
    clearCurrentTenantContext
    withTenantContext 4 404 $ do
      withTenantContext 5 505 (pure ())
      currentTenantContext `shouldReturn` Just (4, 404)
    currentTenantContext `shouldReturn` Nothing

  it "restores the context when the scoped action throws" $ do
    clearCurrentTenantContext
    _ <-
      try (withTenantContext 6 606 (ioError (userError "boom"))) ::
        IO (Either SomeException ())
    currentTenantContext `shouldReturn` Nothing
