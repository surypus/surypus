{-# LANGUAGE OverloadedStrings #-}
-- | Surypus API Classifiers (Phase 1: stub)
module Surypus.API.Classifiers
  ( listOksm
  , getOksm
  , getOksmByCode
  , listOkv
  , getOkv
  , listOkei
  , getOkei
  , listOkpd2
  , getOkpd2
  , listOkved2
  , getOkved2
  , listTnved
  , getTnved
  , listOkato
  , getOkato
  ) where

import Data.Text (Text)
import Data.Int (Int64)

-- | Classifier item
data ClassifierItem = ClassifierItem
  { classifierItemId :: !Int64
  , classifierItemCode :: !Text
  , classifierItemName :: !Text
  } deriving (Show, Eq)

-- | List OKSM (stub)
listOksm :: IO [ClassifierItem]
listOksm = return []

-- | Get OKSM (stub)
getOksm :: Int64 -> IO (Maybe ClassifierItem)
getOksm _ = return Nothing

-- | Get OKSM by code (stub)
getOksmByCode :: Text -> IO (Maybe ClassifierItem)
getOksmByCode _ = return Nothing

-- | List OKV (stub)
listOkv :: IO [ClassifierItem]
listOkv = return []

-- | Get OKV (stub)
getOkv :: Int64 -> IO (Maybe ClassifierItem)
getOkv _ = return Nothing

-- | List OKEI (stub)
listOkei :: IO [ClassifierItem]
listOkei = return []

-- | Get OKEI (stub)
getOkei :: Int64 -> IO (Maybe ClassifierItem)
getOkei _ = return Nothing

-- | List OKPD2 (stub)
listOkpd2 :: IO [ClassifierItem]
listOkpd2 = return []

-- | Get OKPD2 (stub)
getOkpd2 :: Int64 -> IO (Maybe ClassifierItem)
getOkpd2 _ = return Nothing

-- | List OKVED2 (stub)
listOkved2 :: IO [ClassifierItem]
listOkved2 = return []

-- | Get OKVED2 (stub)
getOkved2 :: Int64 -> IO (Maybe ClassifierItem)
getOkved2 _ = return Nothing

-- | List TNVED (stub)
listTnved :: IO [ClassifierItem]
listTnved = return []

-- | Get TNVED (stub)
getTnved :: Int64 -> IO (Maybe ClassifierItem)
getTnved _ = return Nothing

-- | List OKATO (stub)
listOkato :: IO [ClassifierItem]
listOkato = return []

-- | Get OKATO (stub)
getOkato :: Int64 -> IO (Maybe ClassifierItem)
getOkato _ = return Nothing
