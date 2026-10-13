{-# LANGUAGE OverloadedStrings #-}

-- | Tests for Service.WorkflowEngine.
-- Covers the instance lifecycle: create registers a draft instance,
-- executeWorkflowStep advances/completes it, cancel removes it, and the
-- status/list accessors reflect the engine's instance map.  Pins the
-- decisions documented on createWorkflowInstance (description is not
-- stored, instances are step-less, WorkflowConfig is not consulted).
module Service.WorkflowEngineSpec (spec) where

import qualified Data.Text as T
import Service.WorkflowEngine
import Test.Hspec

-- | Engine config with generous limits (limits are not consulted by creation).
testConfig :: WorkflowConfig
testConfig = WorkflowConfig
  { maxConcurrentInstances = 10
  , defaultTimeoutSeconds = 60
  , retryLimit = 3
  }

-- | Assert the state is a completed instance (the completion timestamp is
-- wall-clock, so only the constructor is pinned).
assertCompleted :: Maybe InstanceState -> IO ()
assertCompleted (Just (InstanceCompleted _)) = pure ()
assertCompleted s =
  expectationFailure $ "expected a completed instance, got: " ++ show s

spec :: Spec
spec = describe "Service.WorkflowEngine" $ do

  describe "createWorkflowInstance" $ do
    it "registers the created instance as a draft" $ do
      engine <- initWorkflowEngine testConfig
      iid <- createWorkflowInstance engine "wf-1" "desc"
      status <- getInstanceStatus engine iid
      status `shouldBe` Just InstanceDraft

    it "returns unique workflow-traceable ids" $ do
      engine <- initWorkflowEngine testConfig
      i1 <- createWorkflowInstance engine "wf-1" "first"
      i2 <- createWorkflowInstance engine "wf-1" "second"
      i1 `shouldNotBe` i2
      i1 `shouldSatisfy` T.isPrefixOf "wf-1-inst-"
      i2 `shouldSatisfy` T.isPrefixOf "wf-1-inst-"

    it "accepts any description without affecting the instance" $ do
      engine <- initWorkflowEngine testConfig
      i1 <- createWorkflowInstance engine "wf-2" "first description"
      i2 <- createWorkflowInstance engine "wf-2" "second description"
      s1 <- getInstanceStatus engine i1
      s2 <- getInstanceStatus engine i2
      s1 `shouldBe` Just InstanceDraft
      s2 `shouldBe` Just InstanceDraft

    it "returns different id prefixes for different workflows" $ do
      engine <- initWorkflowEngine testConfig
      i1 <- createWorkflowInstance engine "wf-a" "desc"
      i2 <- createWorkflowInstance engine "wf-b" "desc"
      i1 `shouldSatisfy` T.isPrefixOf "wf-a-inst-"
      i2 `shouldSatisfy` T.isPrefixOf "wf-b-inst-"

  describe "executeWorkflowStep" $ do
    it "reports unknown instances" $ do
      engine <- initWorkflowEngine testConfig
      result <- executeWorkflowStep engine "no-such-instance"
      result `shouldBe` Left "Instance not found"

    it "completes a step-less instance on first execution" $ do
      engine <- initWorkflowEngine testConfig
      iid <- createWorkflowInstance engine "wf-1" "desc"
      result <- executeWorkflowStep engine iid
      result `shouldBe` Right ()
      status <- getInstanceStatus engine iid
      assertCompleted status

    it "refuses to execute a completed instance again" $ do
      engine <- initWorkflowEngine testConfig
      iid <- createWorkflowInstance engine "wf-1" "desc"
      _ <- executeWorkflowStep engine iid
      result <- executeWorkflowStep engine iid
      result `shouldBe` Left "Already completed"

    it "reports a cancelled instance as not found" $ do
      engine <- initWorkflowEngine testConfig
      iid <- createWorkflowInstance engine "wf-1" "desc"
      cancelWorkflowInstance engine iid
      result <- executeWorkflowStep engine iid
      result `shouldBe` Left "Instance not found"

  describe "cancelWorkflowInstance" $ do
    it "removes the instance from the engine" $ do
      engine <- initWorkflowEngine testConfig
      iid <- createWorkflowInstance engine "wf-1" "desc"
      cancelWorkflowInstance engine iid
      status <- getInstanceStatus engine iid
      status `shouldBe` Nothing
      instances <- listWorkflowInstances engine
      instances `shouldBe` []

    it "is a no-op for unknown instances" $ do
      engine <- initWorkflowEngine testConfig
      cancelWorkflowInstance engine "no-such-instance"
      instances <- listWorkflowInstances engine
      instances `shouldBe` []

  describe "listWorkflowInstances" $ do
    it "is empty for a fresh engine" $ do
      engine <- initWorkflowEngine testConfig
      instances <- listWorkflowInstances engine
      instances `shouldBe` []

    it "lists created instances with their state" $ do
      engine <- initWorkflowEngine testConfig
      iid <- createWorkflowInstance engine "wf-1" "desc"
      _ <- executeWorkflowStep engine iid
      instances <- listWorkflowInstances engine
      length instances `shouldBe` 1
      fmap fst instances `shouldBe` [iid]
      assertCompleted (unconsState instances)

-- | Extract the state of the first listed instance (helper for the last test).
unconsState :: [(T.Text, InstanceState)] -> Maybe InstanceState
unconsState [] = Nothing
unconsState ((_, s) : _) = Just s
