{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Classifiers (
    getOksmAll, getOksmById, getOksmByCode,
    getOkvAll, getOkvById, getOkvByCode,
    getOkeiAll, getOkeiById, getOkeiByCode,
    getOkpd2All, getOkpd2ById, getOkpd2ByCode, getOkpd2ByParent,
    getOkved2All, getOkved2ById, getOkved2ByCode, getOkved2ByParent,
    getTnvedAll, getTnvedById, getTnvedByCode, getTnvedByParent,
    getOkatoAll, getOkatoById, getOkatoByCode, getOkatoByParent,
    getOktmoAll, getOktmoById, getOktmoByCode, getOktmoByParent,
    getOkofAll, getOkofById, getOkofByCode, getOkofByParent,
    getOkpAll, getOkpById, getOkpByCode, getOkpByParent,
    getOkdpAll, getOkdpById, getOkdpByCode, getOkdpByParent,
    getOksoAll, getOksoById, getOksoByCode,
    getOkunAll, getOkunById, getOkunByCode, getOkunByParent,
    getOkudAll, getOkudById, getOkudByCode,
    getOkfsAll, getOkfsById, getOkfsByCode,
    getOknpoAll, getOknpoById, getOknpoByCode,
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

getOksmAll :: ConnectionPool -> IO (QueryResult [OksmRecord])
getOksmAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OksmEntity; orderBy [asc $ r ^. OksmEntityCode]; return r) pool
    return $ QuerySuccess (map oksmFromEntity entities)

getOksmById :: ConnectionPool -> Int64 -> IO (QueryResult OksmRecord)
getOksmById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OksmEntity; where_ $ r ^. OksmEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (oksmFromEntity e); _ -> QueryError "Not Found"

getOksmByCode :: ConnectionPool -> Text -> IO (QueryResult OksmRecord)
getOksmByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OksmEntity; where_ $ r ^. OksmEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (oksmFromEntity e); _ -> QueryError "Not Found"

getOkvAll :: ConnectionPool -> IO (QueryResult [OkvRecord])
getOkvAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkvEntity; orderBy [asc $ r ^. OkvEntityCode]; return r) pool
    return $ QuerySuccess (map okvFromEntity entities)

getOkvById :: ConnectionPool -> Int64 -> IO (QueryResult OkvRecord)
getOkvById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkvEntity; where_ $ r ^. OkvEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okvFromEntity e); _ -> QueryError "Not Found"

getOkvByCode :: ConnectionPool -> Text -> IO (QueryResult OkvRecord)
getOkvByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkvEntity; where_ $ r ^. OkvEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okvFromEntity e); _ -> QueryError "Not Found"

getOkeiAll :: ConnectionPool -> IO (QueryResult [OkeiRecord])
getOkeiAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkeiEntity; orderBy [asc $ r ^. OkeiEntityCode]; return r) pool
    return $ QuerySuccess (map okeiFromEntity entities)

getOkeiById :: ConnectionPool -> Int64 -> IO (QueryResult OkeiRecord)
getOkeiById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkeiEntity; where_ $ r ^. OkeiEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okeiFromEntity e); _ -> QueryError "Not Found"

getOkeiByCode :: ConnectionPool -> Text -> IO (QueryResult OkeiRecord)
getOkeiByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkeiEntity; where_ $ r ^. OkeiEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okeiFromEntity e); _ -> QueryError "Not Found"

getOkpd2All :: ConnectionPool -> IO (QueryResult [Okpd2Record])
getOkpd2All pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @Okpd2Entity; orderBy [asc $ r ^. Okpd2EntityCode]; return r) pool
    return $ QuerySuccess (map okpd2FromEntity entities)

getOkpd2ById :: ConnectionPool -> Int64 -> IO (QueryResult Okpd2Record)
getOkpd2ById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @Okpd2Entity; where_ $ r ^. Okpd2EntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okpd2FromEntity e); _ -> QueryError "Not Found"

getOkpd2ByCode :: ConnectionPool -> Text -> IO (QueryResult Okpd2Record)
getOkpd2ByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @Okpd2Entity; where_ $ r ^. Okpd2EntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okpd2FromEntity e); _ -> QueryError "Not Found"

getOkpd2ByParent :: ConnectionPool -> Text -> IO (QueryResult [Okpd2Record])
getOkpd2ByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            r <- from $ table @Okpd2Entity
            where_ $ r ^. Okpd2EntityParentCode ==. val (Just parentCode)
            orderBy [asc $ r ^. Okpd2EntityCode]
            return r) pool
    return $ QuerySuccess (map okpd2FromEntity entities)

getOkved2All :: ConnectionPool -> IO (QueryResult [Okved2Record])
getOkved2All pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @Okved2Entity; orderBy [asc $ r ^. Okved2EntityCode]; return r) pool
    return $ QuerySuccess (map okved2FromEntity entities)

getOkved2ById :: ConnectionPool -> Int64 -> IO (QueryResult Okved2Record)
getOkved2ById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @Okved2Entity; where_ $ r ^. Okved2EntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okved2FromEntity e); _ -> QueryError "Not Found"

getOkved2ByCode :: ConnectionPool -> Text -> IO (QueryResult Okved2Record)
getOkved2ByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @Okved2Entity; where_ $ r ^. Okved2EntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okved2FromEntity e); _ -> QueryError "Not Found"

getOkved2ByParent :: ConnectionPool -> Text -> IO (QueryResult [Okved2Record])
getOkved2ByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            r <- from $ table @Okved2Entity
            where_ $ r ^. Okved2EntityParentCode ==. val (Just parentCode)
            orderBy [asc $ r ^. Okved2EntityCode]
            return r) pool
    return $ QuerySuccess (map okved2FromEntity entities)

getTnvedAll :: ConnectionPool -> IO (QueryResult [TnvedRecord])
getTnvedAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @TnvedEntity; orderBy [asc $ r ^. TnvedEntityCode]; return r) pool
    return $ QuerySuccess (map tnvedFromEntity entities)

getTnvedById :: ConnectionPool -> Int64 -> IO (QueryResult TnvedRecord)
getTnvedById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @TnvedEntity; where_ $ r ^. TnvedEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (tnvedFromEntity e); _ -> QueryError "Not Found"

getTnvedByCode :: ConnectionPool -> Text -> IO (QueryResult TnvedRecord)
getTnvedByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @TnvedEntity; where_ $ r ^. TnvedEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (tnvedFromEntity e); _ -> QueryError "Not Found"

getTnvedByParent :: ConnectionPool -> Text -> IO (QueryResult [TnvedRecord])
getTnvedByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            r <- from $ table @TnvedEntity
            where_ $ r ^. TnvedEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ r ^. TnvedEntityCode]
            return r) pool
    return $ QuerySuccess (map tnvedFromEntity entities)

getOkatoAll :: ConnectionPool -> IO (QueryResult [OkatoRecord])
getOkatoAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkatoEntity; orderBy [asc $ r ^. OkatoEntityCode]; return r) pool
    return $ QuerySuccess (map okatoFromEntity entities)

getOkatoById :: ConnectionPool -> Int64 -> IO (QueryResult OkatoRecord)
getOkatoById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkatoEntity; where_ $ r ^. OkatoEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okatoFromEntity e); _ -> QueryError "Not Found"

getOkatoByCode :: ConnectionPool -> Text -> IO (QueryResult OkatoRecord)
getOkatoByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkatoEntity; where_ $ r ^. OkatoEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okatoFromEntity e); _ -> QueryError "Not Found"

getOkatoByParent :: ConnectionPool -> Text -> IO (QueryResult [OkatoRecord])
getOkatoByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            r <- from $ table @OkatoEntity
            where_ $ r ^. OkatoEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ r ^. OkatoEntityCode]
            return r) pool
    return $ QuerySuccess (map okatoFromEntity entities)

getOktmoAll :: ConnectionPool -> IO (QueryResult [OktmoRecord])
getOktmoAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OktmoEntity; orderBy [asc $ r ^. OktmoEntityCode]; return r) pool
    return $ QuerySuccess (map oktmoFromEntity entities)

getOktmoById :: ConnectionPool -> Int64 -> IO (QueryResult OktmoRecord)
getOktmoById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OktmoEntity; where_ $ r ^. OktmoEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (oktmoFromEntity e); _ -> QueryError "Not Found"

getOktmoByCode :: ConnectionPool -> Text -> IO (QueryResult OktmoRecord)
getOktmoByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OktmoEntity; where_ $ r ^. OktmoEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (oktmoFromEntity e); _ -> QueryError "Not Found"

getOktmoByParent :: ConnectionPool -> Text -> IO (QueryResult [OktmoRecord])
getOktmoByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            r <- from $ table @OktmoEntity
            where_ $ r ^. OktmoEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ r ^. OktmoEntityCode]
            return r) pool
    return $ QuerySuccess (map oktmoFromEntity entities)

getOkofAll :: ConnectionPool -> IO (QueryResult [OkofRecord])
getOkofAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkofEntity; orderBy [asc $ r ^. OkofEntityCode]; return r) pool
    return $ QuerySuccess (map okofFromEntity entities)

getOkofById :: ConnectionPool -> Int64 -> IO (QueryResult OkofRecord)
getOkofById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkofEntity; where_ $ r ^. OkofEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okofFromEntity e); _ -> QueryError "Not Found"

getOkofByCode :: ConnectionPool -> Text -> IO (QueryResult OkofRecord)
getOkofByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkofEntity; where_ $ r ^. OkofEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okofFromEntity e); _ -> QueryError "Not Found"

getOkofByParent :: ConnectionPool -> Text -> IO (QueryResult [OkofRecord])
getOkofByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            r <- from $ table @OkofEntity
            where_ $ r ^. OkofEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ r ^. OkofEntityCode]
            return r) pool
    return $ QuerySuccess (map okofFromEntity entities)

getOkpAll :: ConnectionPool -> IO (QueryResult [OkpRecord])
getOkpAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkpEntity; orderBy [asc $ r ^. OkpEntityCode]; return r) pool
    return $ QuerySuccess (map okpFromEntity entities)

getOkpById :: ConnectionPool -> Int64 -> IO (QueryResult OkpRecord)
getOkpById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkpEntity; where_ $ r ^. OkpEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okpFromEntity e); _ -> QueryError "Not Found"

getOkpByCode :: ConnectionPool -> Text -> IO (QueryResult OkpRecord)
getOkpByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkpEntity; where_ $ r ^. OkpEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okpFromEntity e); _ -> QueryError "Not Found"

getOkpByParent :: ConnectionPool -> Text -> IO (QueryResult [OkpRecord])
getOkpByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            r <- from $ table @OkpEntity
            where_ $ r ^. OkpEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ r ^. OkpEntityCode]
            return r) pool
    return $ QuerySuccess (map okpFromEntity entities)

getOkdpAll :: ConnectionPool -> IO (QueryResult [OkdpRecord])
getOkdpAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkdpEntity; orderBy [asc $ r ^. OkdpEntityCode]; return r) pool
    return $ QuerySuccess (map okdpFromEntity entities)

getOkdpById :: ConnectionPool -> Int64 -> IO (QueryResult OkdpRecord)
getOkdpById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkdpEntity; where_ $ r ^. OkdpEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okdpFromEntity e); _ -> QueryError "Not Found"

getOkdpByCode :: ConnectionPool -> Text -> IO (QueryResult OkdpRecord)
getOkdpByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkdpEntity; where_ $ r ^. OkdpEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okdpFromEntity e); _ -> QueryError "Not Found"

getOkdpByParent :: ConnectionPool -> Text -> IO (QueryResult [OkdpRecord])
getOkdpByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            r <- from $ table @OkdpEntity
            where_ $ r ^. OkdpEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ r ^. OkdpEntityCode]
            return r) pool
    return $ QuerySuccess (map okdpFromEntity entities)

getOksoAll :: ConnectionPool -> IO (QueryResult [OksoRecord])
getOksoAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OksoEntity; orderBy [asc $ r ^. OksoEntityCode]; return r) pool
    return $ QuerySuccess (map oksoFromEntity entities)

getOksoById :: ConnectionPool -> Int64 -> IO (QueryResult OksoRecord)
getOksoById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OksoEntity; where_ $ r ^. OksoEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (oksoFromEntity e); _ -> QueryError "Not Found"

getOksoByCode :: ConnectionPool -> Text -> IO (QueryResult OksoRecord)
getOksoByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OksoEntity; where_ $ r ^. OksoEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (oksoFromEntity e); _ -> QueryError "Not Found"

getOkunAll :: ConnectionPool -> IO (QueryResult [OkunRecord])
getOkunAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkunEntity; orderBy [asc $ r ^. OkunEntityCode]; return r) pool
    return $ QuerySuccess (map okunFromEntity entities)

getOkunById :: ConnectionPool -> Int64 -> IO (QueryResult OkunRecord)
getOkunById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkunEntity; where_ $ r ^. OkunEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okunFromEntity e); _ -> QueryError "Not Found"

getOkunByCode :: ConnectionPool -> Text -> IO (QueryResult OkunRecord)
getOkunByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkunEntity; where_ $ r ^. OkunEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okunFromEntity e); _ -> QueryError "Not Found"

getOkunByParent :: ConnectionPool -> Text -> IO (QueryResult [OkunRecord])
getOkunByParent pool parentCode = do
    entities <- liftIO $ runSqlPool
        (select $ do
            r <- from $ table @OkunEntity
            where_ $ r ^. OkunEntityParentCode ==. val (Just parentCode)
            orderBy [asc $ r ^. OkunEntityCode]
            return r) pool
    return $ QuerySuccess (map okunFromEntity entities)

getOkudAll :: ConnectionPool -> IO (QueryResult [OkudRecord])
getOkudAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkudEntity; orderBy [asc $ r ^. OkudEntityCode]; return r) pool
    return $ QuerySuccess (map okudFromEntity entities)

getOkudById :: ConnectionPool -> Int64 -> IO (QueryResult OkudRecord)
getOkudById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkudEntity; where_ $ r ^. OkudEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okudFromEntity e); _ -> QueryError "Not Found"

getOkudByCode :: ConnectionPool -> Text -> IO (QueryResult OkudRecord)
getOkudByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkudEntity; where_ $ r ^. OkudEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okudFromEntity e); _ -> QueryError "Not Found"

getOkfsAll :: ConnectionPool -> IO (QueryResult [OkfsRecord])
getOkfsAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkfsEntity; orderBy [asc $ r ^. OkfsEntityCode]; return r) pool
    return $ QuerySuccess (map okfsFromEntity entities)

getOkfsById :: ConnectionPool -> Int64 -> IO (QueryResult OkfsRecord)
getOkfsById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkfsEntity; where_ $ r ^. OkfsEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okfsFromEntity e); _ -> QueryError "Not Found"

getOkfsByCode :: ConnectionPool -> Text -> IO (QueryResult OkfsRecord)
getOkfsByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OkfsEntity; where_ $ r ^. OkfsEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (okfsFromEntity e); _ -> QueryError "Not Found"

getOknpoAll :: ConnectionPool -> IO (QueryResult [OknpoRecord])
getOknpoAll pool = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OknpoEntity; orderBy [asc $ r ^. OknpoEntityCode]; return r) pool
    return $ QuerySuccess (map oknpoFromEntity entities)

getOknpoById :: ConnectionPool -> Int64 -> IO (QueryResult OknpoRecord)
getOknpoById pool pid = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OknpoEntity; where_ $ r ^. OknpoEntityId ==. val (toSqlKey pid); return r) pool
    return $ case entities of (e:_) -> QuerySuccess (oknpoFromEntity e); _ -> QueryError "Not Found"

getOknpoByCode :: ConnectionPool -> Text -> IO (QueryResult OknpoRecord)
getOknpoByCode pool code = do
    entities <- liftIO $ runSqlPool
        (select $ do r <- from $ table @OknpoEntity; where_ $ r ^. OknpoEntityCode ==. val code; return r) pool
    return $ case entities of (e:_) -> QuerySuccess (oknpoFromEntity e); _ -> QueryError "Not Found"
