{-# LANGUAGE OverloadedStrings #-}

module EmailSpec (spec) where

import Test.Hspec
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Email

spec :: Spec
spec = do
  describe "Email.defaultEmailConfig" $ do
    it "has correct SMTP defaults" $ do
      let cfg = defaultEmailConfig
      ecSmtpHost cfg `shouldBe` "localhost"
      ecSmtpPort cfg `shouldBe` (587 :: Int)
      ecUsername cfg `shouldBe` ("" :: T.Text)
      ecPassword cfg `shouldBe` ("" :: T.Text)
      ecFromAddr cfg `shouldBe` "noreply@surypus.local"
      ecFromName cfg `shouldBe` "Surypus"
      ecUseTLS cfg `shouldBe` True
      ecOutputFile cfg `shouldBe` (Nothing :: Maybe FilePath)

  describe "Email.sendEmail" $ do
    it "returns Right () when output goes to stdout" $ do
      result <- sendEmail defaultEmailConfig "to@test.com" "Subject" "Body"
      result `shouldBe` (Right () :: Either EmailError ())

    it "writes email content to file when ecOutputFile is set" $ do
      let cfg = defaultEmailConfig { ecOutputFile = Just "/tmp/surypus_email_test.txt" }
      result <- sendEmail cfg "to@test.com" "Subject" "Body"
      result `shouldBe` (Right () :: Either EmailError ())
      content <- TIO.readFile "/tmp/surypus_email_test.txt"
      T.isInfixOf "Subject" content `shouldBe` True
      T.isInfixOf "Body" content `shouldBe` True
      T.isInfixOf "to@test.com" content `shouldBe` True

    it "returns Left EmailSendError when file path is invalid" $ do
      let cfg = defaultEmailConfig { ecOutputFile = Just "/nonexistent/dir/email.txt" }
      result <- sendEmail cfg "to@test.com" "Subject" "Body"
      case result of
        Left (EmailSendError _) -> pure ()
        _ -> fail "Expected Left EmailSendError for invalid file path"

  describe "Email.sendEmailWithRetry" $ do
    it "succeeds on first attempt with valid config" $ do
      result <- sendEmailWithRetry defaultEmailConfig "to@test.com" "Subject" "Body" 3
      result `shouldBe` (Right () :: Either EmailError ())

    it "fails with Max retries exceeded when sendEmail always fails" $ do
      let cfg = defaultEmailConfig { ecOutputFile = Just "/nonexistent/dir/email.txt" }
      result <- sendEmailWithRetry cfg "to@test.com" "Subject" "Body" 2
      case result of
        Left (EmailSendError "Max retries exceeded") -> pure ()
        _ -> fail "Expected Left EmailSendError with Max retries exceeded"
