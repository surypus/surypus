{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Classifiers (
    -- * All classifiers
    listOksm,
    getOksm,
    getOksmByCode,
    listOkv,
    getOkv,
    listOkei,
    getOkei,
    listOkpd2,
    getOkpd2,
    listOkved2,
    getOkved2,
    listTnved,
    getTnved,
    listOkato,
    getOkato,
    listOktmo,
    getOktmo,
    listOkof,
    getOkof,
    listOkp,
    getOkp,
    listOkdp,
    getOkdp,
    listOkso,
    getOkso,
    listOkun,
    getOkun,
    listOkud,
    getOkud,
    listOkfs,
    getOkfs,
    listOknpo,
    getOknpo,
) where

import qualified DAL.Classifiers as C
import DAL.Pool (ConnectionPool)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)

-- OKSM
listOksm :: ConnectionPool -> IO (QueryResult [OksmRecord])
listOksm = C.getOksmAll

getOksm :: ConnectionPool -> Int64 -> IO (QueryResult OksmRecord)
getOksm = C.getOksmById

getOksmByCode :: ConnectionPool -> Text -> IO (QueryResult OksmRecord)
getOksmByCode = C.getOksmByCode

-- OKV
listOkv :: ConnectionPool -> IO (QueryResult [OkvRecord])
listOkv = C.getOkvAll

getOkv :: ConnectionPool -> Int64 -> IO (QueryResult OkvRecord)
getOkv = C.getOkvById

-- OKEI
listOkei :: ConnectionPool -> IO (QueryResult [OkeiRecord])
listOkei = C.getOkeiAll

getOkei :: ConnectionPool -> Int64 -> IO (QueryResult OkeiRecord)
getOkei = C.getOkeiById

-- OKPD2
listOkpd2 :: ConnectionPool -> IO (QueryResult [Okpd2Record])
listOkpd2 = C.getOkpd2All

getOkpd2 :: ConnectionPool -> Int64 -> IO (QueryResult Okpd2Record)
getOkpd2 = C.getOkpd2ById

-- OKVED2
listOkved2 :: ConnectionPool -> IO (QueryResult [Okved2Record])
listOkved2 = C.getOkved2All

getOkved2 :: ConnectionPool -> Int64 -> IO (QueryResult Okved2Record)
getOkved2 = C.getOkved2ById

-- TNVED
listTnved :: ConnectionPool -> IO (QueryResult [TnvedRecord])
listTnved = C.getTnvedAll

getTnved :: ConnectionPool -> Int64 -> IO (QueryResult TnvedRecord)
getTnved = C.getTnvedById

-- OKATO
listOkato :: ConnectionPool -> IO (QueryResult [OkatoRecord])
listOkato = C.getOkatoAll

getOkato :: ConnectionPool -> Int64 -> IO (QueryResult OkatoRecord)
getOkato = C.getOkatoById

-- OKTMO
listOktmo :: ConnectionPool -> IO (QueryResult [OktmoRecord])
listOktmo = C.getOktmoAll

getOktmo :: ConnectionPool -> Int64 -> IO (QueryResult OktmoRecord)
getOktmo = C.getOktmoById

-- OKOF
listOkof :: ConnectionPool -> IO (QueryResult [OkofRecord])
listOkof = C.getOkofAll

getOkof :: ConnectionPool -> Int64 -> IO (QueryResult OkofRecord)
getOkof = C.getOkofById

-- OKP
listOkp :: ConnectionPool -> IO (QueryResult [OkpRecord])
listOkp = C.getOkpAll

getOkp :: ConnectionPool -> Int64 -> IO (QueryResult OkpRecord)
getOkp = C.getOkpById

-- OKDP
listOkdp :: ConnectionPool -> IO (QueryResult [OkdpRecord])
listOkdp = C.getOkdpAll

getOkdp :: ConnectionPool -> Int64 -> IO (QueryResult OkdpRecord)
getOkdp = C.getOkdpById

-- OKSO
listOkso :: ConnectionPool -> IO (QueryResult [OksoRecord])
listOkso = C.getOksoAll

getOkso :: ConnectionPool -> Int64 -> IO (QueryResult OksoRecord)
getOkso = C.getOksoById

-- OKUN
listOkun :: ConnectionPool -> IO (QueryResult [OkunRecord])
listOkun = C.getOkunAll

getOkun :: ConnectionPool -> Int64 -> IO (QueryResult OkunRecord)
getOkun = C.getOkunById

-- OKUD
listOkud :: ConnectionPool -> IO (QueryResult [OkudRecord])
listOkud = C.getOkudAll

getOkud :: ConnectionPool -> Int64 -> IO (QueryResult OkudRecord)
getOkud = C.getOkudById

-- OKFS
listOkfs :: ConnectionPool -> IO (QueryResult [OkfsRecord])
listOkfs = C.getOkfsAll

getOkfs :: ConnectionPool -> Int64 -> IO (QueryResult OkfsRecord)
getOkfs = C.getOkfsById

-- OKNPO
listOknpo :: ConnectionPool -> IO (QueryResult [OknpoRecord])
listOknpo = C.getOknpoAll

getOknpo :: ConnectionPool -> Int64 -> IO (QueryResult OknpoRecord)
getOknpo = C.getOknpoById
