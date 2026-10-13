{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
-- | Surypus API Classifiers
module Surypus.API.Classifiers
  ( ClassifierItem (..)
  , listOksm
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
  , listOkud
  , getOkud
  , listOkfs
  , getOkfs
  , listOknpo
  , getOknpo
  , listOkdp
  , getOkdp
  , listOkso
  , getOkso
  , listOkun
  , getOkun
  , listOktmo
  , getOktmo
  , listOkof
  , getOkof
  , listOkp
  , getOkp
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Data.Int (Int64)
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Types (QueryResult(..))
import GHC.Generics (Generic)

-- | Classifier item
data ClassifierItem = ClassifierItem
  { classifierItemId :: !Int64
  , classifierItemCode :: !Text
  , classifierItemName :: !Text
  } deriving (Show, Eq, Generic)

instance FromJSON ClassifierItem
instance ToJSON ClassifierItem

-- | List OKSM
listOksm :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOksm _ = return $ QuerySuccess []

-- | Get OKSM
getOksm :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOksm _ _ = return $ QuerySuccess Nothing

-- | Get OKSM by code
getOksmByCode :: ConnectionPool -> Text -> IO (QueryResult (Maybe ClassifierItem))
getOksmByCode _ _ = return $ QuerySuccess Nothing

-- | List OKV
listOkv :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkv _ = return $ QuerySuccess []

-- | Get OKV
getOkv :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkv _ _ = return $ QuerySuccess Nothing

-- | List OKEI
listOkei :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkei _ = return $ QuerySuccess []

-- | Get OKEI
getOkei :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkei _ _ = return $ QuerySuccess Nothing

-- | List OKPD2
listOkpd2 :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkpd2 _ = return $ QuerySuccess []

-- | Get OKPD2
getOkpd2 :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkpd2 _ _ = return $ QuerySuccess Nothing

-- | List OKVED2
listOkved2 :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkved2 _ = return $ QuerySuccess []

-- | Get OKVED2
getOkved2 :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkved2 _ _ = return $ QuerySuccess Nothing

-- | List TNVED
listTnved :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listTnved _ = return $ QuerySuccess []

-- | Get TNVED
getTnved :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getTnved _ _ = return $ QuerySuccess Nothing

-- | List OKATO
listOkato :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkato _ = return $ QuerySuccess []

-- | Get OKATO
getOkato :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkato _ _ = return $ QuerySuccess Nothing

-- | List OKUD
listOkud :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkud _ = return $ QuerySuccess []

-- | Get OKUD
getOkud :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkud _ _ = return $ QuerySuccess Nothing

-- | List OKFS
listOkfs :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkfs _ = return $ QuerySuccess []

-- | Get OKFS
getOkfs :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkfs _ _ = return $ QuerySuccess Nothing

-- | List OKNPO
listOknpo :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOknpo _ = return $ QuerySuccess []

-- | Get OKNPO
getOknpo :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOknpo _ _ = return $ QuerySuccess Nothing

-- | List OKDP
listOkdp :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkdp _ = return $ QuerySuccess []

-- | Get OKDP
getOkdp :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkdp _ _ = return $ QuerySuccess Nothing

-- | List OKSO
listOkso :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkso _ = return $ QuerySuccess []

-- | Get OKSO
getOkso :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkso _ _ = return $ QuerySuccess Nothing

-- | List OKUN
listOkun :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkun _ = return $ QuerySuccess []

-- | Get OKUN
getOkun :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkun _ _ = return $ QuerySuccess Nothing

-- | List OKTMO
listOktmo :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOktmo _ = return $ QuerySuccess []

-- | Get OKTMO
getOktmo :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOktmo _ _ = return $ QuerySuccess Nothing

-- | List OKOF
listOkof :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkof _ = return $ QuerySuccess []

-- | Get OKOF
getOkof :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkof _ _ = return $ QuerySuccess Nothing

-- | List OKP
listOkp :: ConnectionPool -> IO (QueryResult [ClassifierItem])
listOkp _ = return $ QuerySuccess []

-- | Get OKP
getOkp :: ConnectionPool -> Int64 -> IO (QueryResult (Maybe ClassifierItem))
getOkp _ _ = return $ QuerySuccess Nothing
