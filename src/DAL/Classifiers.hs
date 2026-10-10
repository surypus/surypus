{-# LANGUAGE OverloadedStrings #-}

module DAL.Classifiers
  ( getOksmAll, getOksmById, getOksmByCode,
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
import qualified Data.Text as T
import Database.Persist.Sql (rawSql, Single(..), PersistValue(..), SqlPersistT)
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Database (ConnectionPool, runDb)
import DAL.Schema
import DAL.Types

-- | Parse a classifier record from raw SQL rows
parseClassifierRow :: (Single PersistValue, Single PersistValue, Single PersistValue) -> (Int64, Text, Text)
parseClassifierRow (Single (PersistInt64 i), Single (PersistText c), Single (PersistText n)) = (i, c, n)
parseClassifierRow _ = (0, "", "")

-- | Parse a classifier record with parent from raw SQL rows
parseClassifierRowParent :: (Single PersistValue, Single PersistValue, Single PersistValue, Single PersistValue) -> (Int64, Text, Text, Maybe Text)
parseClassifierRowParent (Single (PersistInt64 i), Single (PersistText c), Single (PersistText n), p) =
  let parent = case p of Single (PersistText t) -> Just t; _ -> Nothing
  in (i, c, n, parent)
parseClassifierRowParent _ = (0, "", "", Nothing)

-- Helper to run raw SQL queries with 3 columns returning Single PersistValue
runRawSql3 :: Text -> [PersistValue] -> SqlPersistT IO [(Single PersistValue, Single PersistValue, Single PersistValue)]
runRawSql3 = rawSql

-- Helper to run raw SQL queries with 4 columns returning Single PersistValue
runRawSql4 :: Text -> [PersistValue] -> SqlPersistT IO [(Single PersistValue, Single PersistValue, Single PersistValue, Single PersistValue)]
runRawSql4 = rawSql

getOksmAll :: ConnectionPool -> IO (QueryResult [OksmRecord])
getOksmAll pool = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM oksm ORDER BY code") ([] :: [PersistValue])
    let records = [OksmRecord i c n | r <- rows, let (i, c, n) = parseClassifierRow r]
    return $ QuerySuccess records

getOksmById :: ConnectionPool -> Int64 -> IO (QueryResult OksmRecord)
getOksmById pool pid = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM oksm WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OksmRecord i c n)
        _ -> QueryError "Not Found"

getOksmByCode :: ConnectionPool -> Text -> IO (QueryResult OksmRecord)
getOksmByCode pool code = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM oksm WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OksmRecord i c n)
        _ -> QueryError "Not Found"

getOkvAll :: ConnectionPool -> IO (QueryResult [OkvRecord])
getOkvAll pool = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okv ORDER BY code") ([] :: [PersistValue])
    let records = [OkvRecord i c n | r <- rows, let (i, c, n) = parseClassifierRow r]
    return $ QuerySuccess records

getOkvById :: ConnectionPool -> Int64 -> IO (QueryResult OkvRecord)
getOkvById pool pid = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okv WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OkvRecord i c n)
        _ -> QueryError "Not Found"

getOkvByCode :: ConnectionPool -> Text -> IO (QueryResult OkvRecord)
getOkvByCode pool code = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okv WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OkvRecord i c n)
        _ -> QueryError "Not Found"

getOkeiAll :: ConnectionPool -> IO (QueryResult [OkeiRecord])
getOkeiAll pool = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okei ORDER BY code") ([] :: [PersistValue])
    let records = [OkeiRecord i c n | r <- rows, let (i, c, n) = parseClassifierRow r]
    return $ QuerySuccess records

getOkeiById :: ConnectionPool -> Int64 -> IO (QueryResult OkeiRecord)
getOkeiById pool pid = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okei WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OkeiRecord i c n)
        _ -> QueryError "Not Found"

getOkeiByCode :: ConnectionPool -> Text -> IO (QueryResult OkeiRecord)
getOkeiByCode pool code = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okei WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OkeiRecord i c n)
        _ -> QueryError "Not Found"

getOkpd2All :: ConnectionPool -> IO (QueryResult [Okpd2Record])
getOkpd2All pool = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okpd2 ORDER BY code") ([] :: [PersistValue])
    let records = [Okpd2Record i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkpd2ById :: ConnectionPool -> Int64 -> IO (QueryResult Okpd2Record)
getOkpd2ById pool pid = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okpd2 WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (Okpd2Record i c n p)
        _ -> QueryError "Not Found"

getOkpd2ByCode :: ConnectionPool -> Text -> IO (QueryResult Okpd2Record)
getOkpd2ByCode pool code = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okpd2 WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (Okpd2Record i c n p)
        _ -> QueryError "Not Found"

getOkpd2ByParent :: ConnectionPool -> Text -> IO (QueryResult [Okpd2Record])
getOkpd2ByParent pool parentCode = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okpd2 WHERE parent_code = ? ORDER BY code") [PersistText parentCode]
    let records = [Okpd2Record i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkved2All :: ConnectionPool -> IO (QueryResult [Okved2Record])
getOkved2All pool = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okved2 ORDER BY code") ([] :: [PersistValue])
    let records = [Okved2Record i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkved2ById :: ConnectionPool -> Int64 -> IO (QueryResult Okved2Record)
getOkved2ById pool pid = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okved2 WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (Okved2Record i c n p)
        _ -> QueryError "Not Found"

getOkved2ByCode :: ConnectionPool -> Text -> IO (QueryResult Okved2Record)
getOkved2ByCode pool code = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okved2 WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (Okved2Record i c n p)
        _ -> QueryError "Not Found"

getOkved2ByParent :: ConnectionPool -> Text -> IO (QueryResult [Okved2Record])
getOkved2ByParent pool parentCode = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okved2 WHERE parent_code = ? ORDER BY code") [PersistText parentCode]
    let records = [Okved2Record i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getTnvedAll :: ConnectionPool -> IO (QueryResult [TnvedRecord])
getTnvedAll pool = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM tnved ORDER BY code") ([] :: [PersistValue])
    let records = [TnvedRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getTnvedById :: ConnectionPool -> Int64 -> IO (QueryResult TnvedRecord)
getTnvedById pool pid = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM tnved WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (TnvedRecord i c n p)
        _ -> QueryError "Not Found"

getTnvedByCode :: ConnectionPool -> Text -> IO (QueryResult TnvedRecord)
getTnvedByCode pool code = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM tnved WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (TnvedRecord i c n p)
        _ -> QueryError "Not Found"

getTnvedByParent :: ConnectionPool -> Text -> IO (QueryResult [TnvedRecord])
getTnvedByParent pool parentCode = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM tnved WHERE parent_code = ? ORDER BY code") [PersistText parentCode]
    let records = [TnvedRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkatoAll :: ConnectionPool -> IO (QueryResult [OkatoRecord])
getOkatoAll pool = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okato ORDER BY code") ([] :: [PersistValue])
    let records = [OkatoRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkatoById :: ConnectionPool -> Int64 -> IO (QueryResult OkatoRecord)
getOkatoById pool pid = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okato WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OkatoRecord i c n p)
        _ -> QueryError "Not Found"

getOkatoByCode :: ConnectionPool -> Text -> IO (QueryResult OkatoRecord)
getOkatoByCode pool code = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okato WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OkatoRecord i c n p)
        _ -> QueryError "Not Found"

getOkatoByParent :: ConnectionPool -> Text -> IO (QueryResult [OkatoRecord])
getOkatoByParent pool parentCode = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okato WHERE parent_code = ? ORDER BY code") [PersistText parentCode]
    let records = [OkatoRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOktmoAll :: ConnectionPool -> IO (QueryResult [OktmoRecord])
getOktmoAll pool = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM oktmo ORDER BY code") ([] :: [PersistValue])
    let records = [OktmoRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOktmoById :: ConnectionPool -> Int64 -> IO (QueryResult OktmoRecord)
getOktmoById pool pid = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM oktmo WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OktmoRecord i c n p)
        _ -> QueryError "Not Found"

getOktmoByCode :: ConnectionPool -> Text -> IO (QueryResult OktmoRecord)
getOktmoByCode pool code = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM oktmo WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OktmoRecord i c n p)
        _ -> QueryError "Not Found"

getOktmoByParent :: ConnectionPool -> Text -> IO (QueryResult [OktmoRecord])
getOktmoByParent pool parentCode = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM oktmo WHERE parent_code = ? ORDER BY code") [PersistText parentCode]
    let records = [OktmoRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkofAll :: ConnectionPool -> IO (QueryResult [OkofRecord])
getOkofAll pool = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okof ORDER BY code") ([] :: [PersistValue])
    let records = [OkofRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkofById :: ConnectionPool -> Int64 -> IO (QueryResult OkofRecord)
getOkofById pool pid = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okof WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OkofRecord i c n p)
        _ -> QueryError "Not Found"

getOkofByCode :: ConnectionPool -> Text -> IO (QueryResult OkofRecord)
getOkofByCode pool code = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okof WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OkofRecord i c n p)
        _ -> QueryError "Not Found"

getOkofByParent :: ConnectionPool -> Text -> IO (QueryResult [OkofRecord])
getOkofByParent pool parentCode = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okof WHERE parent_code = ? ORDER BY code") [PersistText parentCode]
    let records = [OkofRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkpAll :: ConnectionPool -> IO (QueryResult [OkpRecord])
getOkpAll pool = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okp ORDER BY code") ([] :: [PersistValue])
    let records = [OkpRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkpById :: ConnectionPool -> Int64 -> IO (QueryResult OkpRecord)
getOkpById pool pid = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okp WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OkpRecord i c n p)
        _ -> QueryError "Not Found"

getOkpByCode :: ConnectionPool -> Text -> IO (QueryResult OkpRecord)
getOkpByCode pool code = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okp WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OkpRecord i c n p)
        _ -> QueryError "Not Found"

getOkpByParent :: ConnectionPool -> Text -> IO (QueryResult [OkpRecord])
getOkpByParent pool parentCode = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okp WHERE parent_code = ? ORDER BY code") [PersistText parentCode]
    let records = [OkpRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkdpAll :: ConnectionPool -> IO (QueryResult [OkdpRecord])
getOkdpAll pool = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okdp ORDER BY code") ([] :: [PersistValue])
    let records = [OkdpRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkdpById :: ConnectionPool -> Int64 -> IO (QueryResult OkdpRecord)
getOkdpById pool pid = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okdp WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OkdpRecord i c n p)
        _ -> QueryError "Not Found"

getOkdpByCode :: ConnectionPool -> Text -> IO (QueryResult OkdpRecord)
getOkdpByCode pool code = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okdp WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OkdpRecord i c n p)
        _ -> QueryError "Not Found"

getOkdpByParent :: ConnectionPool -> Text -> IO (QueryResult [OkdpRecord])
getOkdpByParent pool parentCode = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okdp WHERE parent_code = ? ORDER BY code") [PersistText parentCode]
    let records = [OkdpRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOksoAll :: ConnectionPool -> IO (QueryResult [OksoRecord])
getOksoAll pool = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okso ORDER BY code") ([] :: [PersistValue])
    let records = [OksoRecord i c n | r <- rows, let (i, c, n) = parseClassifierRow r]
    return $ QuerySuccess records

getOksoById :: ConnectionPool -> Int64 -> IO (QueryResult OksoRecord)
getOksoById pool pid = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okso WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OksoRecord i c n)
        _ -> QueryError "Not Found"

getOksoByCode :: ConnectionPool -> Text -> IO (QueryResult OksoRecord)
getOksoByCode pool code = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okso WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OksoRecord i c n)
        _ -> QueryError "Not Found"

getOkunAll :: ConnectionPool -> IO (QueryResult [OkunRecord])
getOkunAll pool = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okun ORDER BY code") ([] :: [PersistValue])
    let records = [OkunRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkunById :: ConnectionPool -> Int64 -> IO (QueryResult OkunRecord)
getOkunById pool pid = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okun WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OkunRecord i c n p)
        _ -> QueryError "Not Found"

getOkunByCode :: ConnectionPool -> Text -> IO (QueryResult OkunRecord)
getOkunByCode pool code = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okun WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n, p) = parseClassifierRowParent r in QuerySuccess (OkunRecord i c n p)
        _ -> QueryError "Not Found"

getOkunByParent :: ConnectionPool -> Text -> IO (QueryResult [OkunRecord])
getOkunByParent pool parentCode = do
    rows <- runDb pool $ runRawSql4 ("SELECT id, code, name, parent_code FROM okun WHERE parent_code = ? ORDER BY code") [PersistText parentCode]
    let records = [OkunRecord i c n p | r <- rows, let (i, c, n, p) = parseClassifierRowParent r]
    return $ QuerySuccess records

getOkudAll :: ConnectionPool -> IO (QueryResult [OkudRecord])
getOkudAll pool = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okud ORDER BY code") ([] :: [PersistValue])
    let records = [OkudRecord i c n | r <- rows, let (i, c, n) = parseClassifierRow r]
    return $ QuerySuccess records

getOkudById :: ConnectionPool -> Int64 -> IO (QueryResult OkudRecord)
getOkudById pool pid = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okud WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OkudRecord i c n)
        _ -> QueryError "Not Found"

getOkudByCode :: ConnectionPool -> Text -> IO (QueryResult OkudRecord)
getOkudByCode pool code = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okud WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OkudRecord i c n)
        _ -> QueryError "Not Found"

getOkfsAll :: ConnectionPool -> IO (QueryResult [OkfsRecord])
getOkfsAll pool = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okfs ORDER BY code") ([] :: [PersistValue])
    let records = [OkfsRecord i c n | r <- rows, let (i, c, n) = parseClassifierRow r]
    return $ QuerySuccess records

getOkfsById :: ConnectionPool -> Int64 -> IO (QueryResult OkfsRecord)
getOkfsById pool pid = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okfs WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OkfsRecord i c n)
        _ -> QueryError "Not Found"

getOkfsByCode :: ConnectionPool -> Text -> IO (QueryResult OkfsRecord)
getOkfsByCode pool code = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM okfs WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OkfsRecord i c n)
        _ -> QueryError "Not Found"

getOknpoAll :: ConnectionPool -> IO (QueryResult [OknpoRecord])
getOknpoAll pool = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM oknpo ORDER BY code") ([] :: [PersistValue])
    let records = [OknpoRecord i c n | r <- rows, let (i, c, n) = parseClassifierRow r]
    return $ QuerySuccess records

getOknpoById :: ConnectionPool -> Int64 -> IO (QueryResult OknpoRecord)
getOknpoById pool pid = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM oknpo WHERE id = ?") [PersistInt64 pid]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OknpoRecord i c n)
        _ -> QueryError "Not Found"

getOknpoByCode :: ConnectionPool -> Text -> IO (QueryResult OknpoRecord)
getOknpoByCode pool code = do
    rows <- runDb pool $ runRawSql3 ("SELECT id, code, name FROM oknpo WHERE code = ?") [PersistText code]
    return $ case rows of
        (r:_) -> let (i, c, n) = parseClassifierRow r in QuerySuccess (OknpoRecord i c n)
        _ -> QueryError "Not Found"
