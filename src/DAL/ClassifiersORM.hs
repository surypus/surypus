{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

module DAL.ClassifiersORM (
    -- * OKSM
    getOksmAll,
    getOksmById,
    getOksmByCode,

    -- * OKV
    getOkvAll,
    getOkvById,
    getOkvByCode,

    -- * OKEI
    getOkeiAll,
    getOkeiById,
    getOkeiByCode,

    -- * OKPD2
    getOkpd2All,
    getOkpd2ById,
    getOkpd2ByCode,
    getOkpd2ByParent,

    -- * OKVED2
    getOkved2All,
    getOkved2ById,
    getOkved2ByCode,
    getOkved2ByParent,

    -- * TNVED
    getTnvedAll,
    getTnvedById,
    getTnvedByCode,
    getTnvedByParent,

    -- * OKATO
    getOkatoAll,
    getOkatoById,
    getOkatoByCode,
    getOkatoByParent,

    -- * OKTMO
    getOktmoAll,
    getOktmoById,
    getOktmoByCode,
    getOktmoByParent,

    -- * OKOF
    getOkofAll,
    getOkofById,
    getOkofByCode,
    getOkofByParent,

    -- * OKP
    getOkpAll,
    getOkpById,
    getOkpByCode,
    getOkpByParent,

    -- * OKDP
    getOkdpAll,
    getOkdpById,
    getOkdpByCode,
    getOkdpByParent,

    -- * OKSO
    getOksoAll,
    getOksoById,
    getOksoByCode,

    -- * OKUN
    getOkunAll,
    getOkunById,
    getOkunByCode,
    getOkunByParent,

    -- * OKUD
    getOkudAll,
    getOkudById,
    getOkudByCode,

    -- * OKFS
    getOkfsAll,
    getOkfsById,
    getOkfsByCode,

    -- * OKNPO
    getOknpoAll,
    getOknpoById,
    getOknpoByCode
) where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Text (Text)
import Database.Esqueleto.Experimental
import Database.Persist.Sql (runSqlPool, toSqlKey)
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Schema
import DAL.Types
import DAL.Conversion

-- | Get all OKSM records
getOksmAll :: ConnectionPool -> IO (QueryResult [OksmRecord])
getOksmAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OksmEntity
            orderBy [asc $ o ^. OksmEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map oksmFromEntity entities

getOksmById :: ConnectionPool -> Int64 -> IO (QueryResult OksmRecord)
getOksmById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OksmEntity
            where_ $ o ^. OksmEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ oksmFromEntity entity
        Nothing -> QueryError "Not Found"

getOksmByCode :: ConnectionPool -> Text -> IO (QueryResult OksmRecord)
getOksmByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OksmEntity
            where_ $ o ^. OksmEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ oksmFromEntity entity
        Nothing -> QueryError "Not Found"

-- | Get all OKV records
getOkvAll :: ConnectionPool -> IO (QueryResult [OkvRecord])
getOkvAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkvEntity
            orderBy [asc $ o ^. OkvEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okvFromEntity entities

getOkvById :: ConnectionPool -> Int64 -> IO (QueryResult OkvRecord)
getOkvById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkvEntity
            where_ $ o ^. OkvEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okvFromEntity entity
        Nothing -> QueryError "Not Found"

getOkvByCode :: ConnectionPool -> Text -> IO (QueryResult OkvRecord)
getOkvByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkvEntity
            where_ $ o ^. OkvEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okvFromEntity entity
        Nothing -> QueryError "Not Found"

-- | Get all OKEI records
getOkeiAll :: ConnectionPool -> IO (QueryResult [OkeiRecord])
getOkeiAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkeiEntity
            orderBy [asc $ o ^. OkeiEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okeiFromEntity entities

getOkeiById :: ConnectionPool -> Int64 -> IO (QueryResult OkeiRecord)
getOkeiById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkeiEntity
            where_ $ o ^. OkeiEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okeiFromEntity entity
        Nothing -> QueryError "Not Found"

getOkeiByCode :: ConnectionPool -> Text -> IO (QueryResult OkeiRecord)
getOkeiByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkeiEntity
            where_ $ o ^. OkeiEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okeiFromEntity entity
        Nothing -> QueryError "Not Found"

-- | Get all OKPD2 records
getOkpd2All :: ConnectionPool -> IO (QueryResult [Okpd2Record])
getOkpd2All pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @Okpd2Entity
            orderBy [asc $ o ^. Okpd2EntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okpd2FromEntity entities

getOkpd2ById :: ConnectionPool -> Int64 -> IO (QueryResult Okpd2Record)
getOkpd2ById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @Okpd2Entity
            where_ $ o ^. Okpd2EntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okpd2FromEntity entity
        Nothing -> QueryError "Not Found"

getOkpd2ByCode :: ConnectionPool -> Text -> IO (QueryResult Okpd2Record)
getOkpd2ByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @Okpd2Entity
            where_ $ o ^. Okpd2EntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okpd2FromEntity entity
        Nothing -> QueryError "Not Found"

getOkpd2ByParent :: ConnectionPool -> Text -> IO (QueryResult [Okpd2Record])
getOkpd2ByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @Okpd2Entity
            where_ $ o ^. Okpd2EntityParentCode ==. val (Just parentCode)
            orderBy [asc $ o ^. Okpd2EntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okpd2FromEntity entities

-- | Get all OKVED2 records
getOkved2All :: ConnectionPool -> IO (QueryResult [Okved2Record])
getOkved2All pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @Okved2Entity
            orderBy [asc $ o ^. Okved2EntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okved2FromEntity entities

getOkved2ById :: ConnectionPool -> Int64 -> IO (QueryResult Okved2Record)
getOkved2ById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @Okved2Entity
            where_ $ o ^. Okved2EntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okved2FromEntity entity
        Nothing -> QueryError "Not Found"

getOkved2ByCode :: ConnectionPool -> Text -> IO (QueryResult Okved2Record)
getOkved2ByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @Okved2Entity
            where_ $ o ^. Okved2EntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okved2FromEntity entity
        Nothing -> QueryError "Not Found"

getOkved2ByParent :: ConnectionPool -> Text -> IO (QueryResult [Okved2Record])
getOkved2ByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @Okved2Entity
            where_ $ o ^. Okved2EntityParentCode ==. val (Just parentCode)
            orderBy [asc $ o ^. Okved2EntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okved2FromEntity entities

-- | Get all TNVED records
getTnvedAll :: ConnectionPool -> IO (QueryResult [TnvedRecord])
getTnvedAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @TnvedEntity
            orderBy [asc $ o ^. TnvedEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map tnvedFromEntity entities

getTnvedById :: ConnectionPool -> Int64 -> IO (QueryResult TnvedRecord)
getTnvedById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @TnvedEntity
            where_ $ o ^. TnvedEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ tnvedFromEntity entity
        Nothing -> QueryError "Not Found"

getTnvedByCode :: ConnectionPool -> Text -> IO (QueryResult TnvedRecord)
getTnvedByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @TnvedEntity
            where_ $ o ^. TnvedEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ tnvedFromEntity entity
        Nothing -> QueryError "Not Found"

getTnvedByParent :: ConnectionPool -> Text -> IO (QueryResult [TnvedRecord])
getTnvedByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @TnvedEntity
            where_ $ o ^. TnvedEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ o ^. TnvedEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map tnvedFromEntity entities

-- | Get all OKATO records
getOkatoAll :: ConnectionPool -> IO (QueryResult [OkatoRecord])
getOkatoAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkatoEntity
            orderBy [asc $ o ^. OkatoEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okatoFromEntity entities

getOkatoById :: ConnectionPool -> Int64 -> IO (QueryResult OkatoRecord)
getOkatoById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkatoEntity
            where_ $ o ^. OkatoEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okatoFromEntity entity
        Nothing -> QueryError "Not Found"

getOkatoByCode :: ConnectionPool -> Text -> IO (QueryResult OkatoRecord)
getOkatoByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkatoEntity
            where_ $ o ^. OkatoEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okatoFromEntity entity
        Nothing -> QueryError "Not Found"

getOkatoByParent :: ConnectionPool -> Text -> IO (QueryResult [OkatoRecord])
getOkatoByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkatoEntity
            where_ $ o ^. OkatoEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ o ^. OkatoEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okatoFromEntity entities

-- | Get all OKTMO records
getOktmoAll :: ConnectionPool -> IO (QueryResult [OktmoRecord])
getOktmoAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OktmoEntity
            orderBy [asc $ o ^. OktmoEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map oktmoFromEntity entities

getOktmoById :: ConnectionPool -> Int64 -> IO (QueryResult OktmoRecord)
getOktmoById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OktmoEntity
            where_ $ o ^. OktmoEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ oktmoFromEntity entity
        Nothing -> QueryError "Not Found"

getOktmoByCode :: ConnectionPool -> Text -> IO (QueryResult OktmoRecord)
getOktmoByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OktmoEntity
            where_ $ o ^. OktmoEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ oktmoFromEntity entity
        Nothing -> QueryError "Not Found"

getOktmoByParent :: ConnectionPool -> Text -> IO (QueryResult [OktmoRecord])
getOktmoByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OktmoEntity
            where_ $ o ^. OktmoEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ o ^. OktmoEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map oktmoFromEntity entities

-- | Get all OKOF records
getOkofAll :: ConnectionPool -> IO (QueryResult [OkofRecord])
getOkofAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkofEntity
            orderBy [asc $ o ^. OkofEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okofFromEntity entities

getOkofById :: ConnectionPool -> Int64 -> IO (QueryResult OkofRecord)
getOkofById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkofEntity
            where_ $ o ^. OkofEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okofFromEntity entity
        Nothing -> QueryError "Not Found"

getOkofByCode :: ConnectionPool -> Text -> IO (QueryResult OkofRecord)
getOkofByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkofEntity
            where_ $ o ^. OkofEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okofFromEntity entity
        Nothing -> QueryError "Not Found"

getOkofByParent :: ConnectionPool -> Text -> IO (QueryResult [OkofRecord])
getOkofByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkofEntity
            where_ $ o ^. OkofEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ o ^. OkofEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okofFromEntity entities

-- | Get all OKP records
getOkpAll :: ConnectionPool -> IO (QueryResult [OkpRecord])
getOkpAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkpEntity
            orderBy [asc $ o ^. OkpEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okpFromEntity entities

getOkpById :: ConnectionPool -> Int64 -> IO (QueryResult OkpRecord)
getOkpById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkpEntity
            where_ $ o ^. OkpEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okpFromEntity entity
        Nothing -> QueryError "Not Found"

getOkpByCode :: ConnectionPool -> Text -> IO (QueryResult OkpRecord)
getOkpByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkpEntity
            where_ $ o ^. OkpEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okpFromEntity entity
        Nothing -> QueryError "Not Found"

getOkpByParent :: ConnectionPool -> Text -> IO (QueryResult [OkpRecord])
getOkpByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkpEntity
            where_ $ o ^. OkpEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ o ^. OkpEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okpFromEntity entities

-- | Get all OKDP records
getOkdpAll :: ConnectionPool -> IO (QueryResult [OkdpRecord])
getOkdpAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkdpEntity
            orderBy [asc $ o ^. OkdpEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okdpFromEntity entities

getOkdpById :: ConnectionPool -> Int64 -> IO (QueryResult OkdpRecord)
getOkdpById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkdpEntity
            where_ $ o ^. OkdpEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okdpFromEntity entity
        Nothing -> QueryError "Not Found"

getOkdpByCode :: ConnectionPool -> Text -> IO (QueryResult OkdpRecord)
getOkdpByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkdpEntity
            where_ $ o ^. OkdpEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okdpFromEntity entity
        Nothing -> QueryError "Not Found"

getOkdpByParent :: ConnectionPool -> Text -> IO (QueryResult [OkdpRecord])
getOkdpByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkdpEntity
            where_ $ o ^. OkdpEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ o ^. OkdpEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okdpFromEntity entities

-- | Get all OKSO records
getOksoAll :: ConnectionPool -> IO (QueryResult [OksoRecord])
getOksoAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OksoEntity
            orderBy [asc $ o ^. OksoEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map oksoFromEntity entities

getOksoById :: ConnectionPool -> Int64 -> IO (QueryResult OksoRecord)
getOksoById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OksoEntity
            where_ $ o ^. OksoEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ oksoFromEntity entity
        Nothing -> QueryError "Not Found"

getOksoByCode :: ConnectionPool -> Text -> IO (QueryResult OksoRecord)
getOksoByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OksoEntity
            where_ $ o ^. OksoEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ oksoFromEntity entity
        Nothing -> QueryError "Not Found"

-- | Get all OKUN records
getOkunAll :: ConnectionPool -> IO (QueryResult [OkunRecord])
getOkunAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkunEntity
            orderBy [asc $ o ^. OkunEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okunFromEntity entities

getOkunById :: ConnectionPool -> Int64 -> IO (QueryResult OkunRecord)
getOkunById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkunEntity
            where_ $ o ^. OkunEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okunFromEntity entity
        Nothing -> QueryError "Not Found"

getOkunByCode :: ConnectionPool -> Text -> IO (QueryResult OkunRecord)
getOkunByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkunEntity
            where_ $ o ^. OkunEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okunFromEntity entity
        Nothing -> QueryError "Not Found"

getOkunByParent :: ConnectionPool -> Text -> IO (QueryResult [OkunRecord])
getOkunByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkunEntity
            where_ $ o ^. OkunEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ o ^. OkunEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okunFromEntity entities

-- | Get all OKUD records
getOkudAll :: ConnectionPool -> IO (QueryResult [OkudRecord])
getOkudAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkudEntity
            orderBy [asc $ o ^. OkudEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okudFromEntity entities

getOkudById :: ConnectionPool -> Int64 -> IO (QueryResult OkudRecord)
getOkudById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkudEntity
            where_ $ o ^. OkudEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okudFromEntity entity
        Nothing -> QueryError "Not Found"

getOkudByCode :: ConnectionPool -> Text -> IO (QueryResult OkudRecord)
getOkudByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkudEntity
            where_ $ o ^. OkudEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okudFromEntity entity
        Nothing -> QueryError "Not Found"

-- | Get all OKFS records
getOkfsAll :: ConnectionPool -> IO (QueryResult [OkfsRecord])
getOkfsAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OkfsEntity
            orderBy [asc $ o ^. OkfsEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map okfsFromEntity entities

getOkfsById :: ConnectionPool -> Int64 -> IO (QueryResult OkfsRecord)
getOkfsById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkfsEntity
            where_ $ o ^. OkfsEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okfsFromEntity entity
        Nothing -> QueryError "Not Found"

getOkfsByCode :: ConnectionPool -> Text -> IO (QueryResult OkfsRecord)
getOkfsByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OkfsEntity
            where_ $ o ^. OkfsEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ okfsFromEntity entity
        Nothing -> QueryError "Not Found"

-- | Get all OKNPO records
getOknpoAll :: ConnectionPool -> IO (QueryResult [OknpoRecord])
getOknpoAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            o <- from $ table @OknpoEntity
            orderBy [asc $ o ^. OknpoEntityCode]
            return o)
        pool
    return $ QuerySuccess $ map oknpoFromEntity entities

getOknpoById :: ConnectionPool -> Int64 -> IO (QueryResult OknpoRecord)
getOknpoById pool oid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OknpoEntity
            where_ $ o ^. OknpoEntityId ==. val (toSqlKey oid)
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ oknpoFromEntity entity
        Nothing -> QueryError "Not Found"

getOknpoByCode :: ConnectionPool -> Text -> IO (QueryResult OknpoRecord)
getOknpoByCode pool code = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            o <- from $ table @OknpoEntity
            where_ $ o ^. OknpoEntityCode ==. val code
            return o)
        pool
    return $ case result of
        Just entity -> QuerySuccess $ oknpoFromEntity entity
        Nothing -> QueryError "Not Found"
