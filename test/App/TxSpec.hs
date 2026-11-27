{-# LANGUAGE OverloadedStrings #-}
module App.TxSpec (spec) where

import Data.Map.Strict (empty)
import qualified Data.Map.Strict as M
import Data.Time.Calendar (fromGregorian)
import Test.Hspec
import App.Tx
import Finance.Account (AccountCode (..))
import Finance.Ledger
  ( Amount (..)
  , CurrencyCode (..)
  , Ledger (..)
  , TransactionDate (..)
  , TurnId (..)
  , createTurn
  , ledgerEntries
  )

spec :: Spec
spec = describe "App.Tx.runWrite" $ do
  let day = TransactionDate (fromGregorian 2026 1 1)
      base = Ledger empty empty (CurrencyCode "RUB")
      key = IdempotencyKey "bill-1"
      balanced = createTurn (TurnId 1) (AccountCode "10") (AccountCode "60") (Amount 100) day
      unbalanced = createTurn (TurnId 2) (AccountCode "10") (AccountCode "50") (Amount 100) day

  it "accepts a balanced entry" $ do
    case runWrite key (emptyTxState base) balanced of
      Left err -> expectationFailure ("unexpected rejection: " <> show err)
      Right st -> M.size (ledgerEntries (txLedger st)) `shouldBe` 1

  it "rejects an unbalanced entry" $ do
    runWrite key (emptyTxState base) unbalanced `shouldBe` Left UnbalancedEntry

  it "treats a repeated key as a replay" $ do
    case runWrite key (emptyTxState base) balanced of
      Left err -> expectationFailure ("unexpected rejection: " <> show err)
      Right once -> case runWrite key once balanced of
        Left err -> expectationFailure ("unexpected replay rejection: " <> show err)
        Right twice -> twice `shouldBe` once
