-- | DAL ClassifiersORM - raw SQL queries for classifiers
module DAL.ClassifiersORM
  ( getOksmAll, getOksmById, getOksmByCode
  , getOkvAll, getOkvById, getOkvByCode
  , getOkeiAll, getOkeiById, getOkeiByCode
  , getOkpd2All, getOkpd2ById, getOkpd2ByCode, getOkpd2ByParent
  , getOkved2All, getOkved2ById, getOkved2ByCode, getOkved2ByParent
  , getTnvedAll, getTnvedById, getTnvedByCode, getTnvedByParent
  , getOkatoAll, getOkatoById, getOkatoByCode, getOkatoByParent
  , getOktmoAll, getOktmoById, getOktmoByCode, getOktmoByParent
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Sql (rawSql, Single(..), PersistValue(..))
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Database (ConnectionPool, runDb)

data ClassifierItem = ClassifierItem
  { classifierItemId :: !Int64
  , classifierItemCode :: !Text
  , classifierItemName :: !Text
  , classifierItemDescription :: !(Maybe Text)
  , classifierItemParentId :: !(Maybe Int64)
  } deriving (Show, Eq)

toItemId :: PersistValue -> Int64
toItemId (PersistInt64 n) = n
toItemId _ = 0

toItemText :: PersistValue -> Text
toItemText (PersistText t) = t
toItemText (PersistInt64 n) = T.pack $ show n
toItemText _ = T.empty

toItemMaybeText :: PersistValue -> Maybe Text
toItemMaybeText PersistNull = Nothing
toItemMaybeText v = Just $ toItemText v

toItemMaybeInt64 :: PersistValue -> Maybe Int64
toItemMaybeInt64 PersistNull = Nothing
toItemMaybeInt64 (PersistInt64 n) = Just n
toItemMaybeInt64 _ = Nothing

parseRow :: [PersistValue] -> ClassifierItem
parseRow (id':code:name:desc:parent:_) = ClassifierItem
  { classifierItemId = toItemId id'
  , classifierItemCode = toItemText code
  , classifierItemName = toItemText name
  , classifierItemDescription = toItemMaybeText desc
  , classifierItemParentId = toItemMaybeInt64 parent
  }
parseRow _ = ClassifierItem 0 T.empty T.empty Nothing Nothing

getAllClassifiers :: ConnectionPool -> Text -> IO [ClassifierItem]
getAllClassifiers pool table = do
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " ORDER BY id"
  rows <- runDb pool $ rawSql sql [] :: IO [Single PersistValue]
  return $ map (parseRow . (\(Single v) -> [v])) rows

getClassifierById :: ConnectionPool -> Text -> Int64 -> IO (Maybe ClassifierItem)
getClassifierById pool table id' = do
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " WHERE id = ?"
  rows <- runDb pool $ rawSql sql [PersistInt64 id'] :: IO [Single PersistValue]
  case rows of
    (Single v : _) -> return $ Just $ parseRow [v]
    _ -> return Nothing

getClassifierByCode :: ConnectionPool -> Text -> Text -> IO (Maybe ClassifierItem)
getClassifierByCode pool table code = do
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " WHERE code = ?"
  rows <- runDb pool $ rawSql sql [PersistText code] :: IO [Single PersistValue]
  case rows of
    (Single v : _) -> return $ Just $ parseRow [v]
    _ -> return Nothing

getClassifierByParent :: ConnectionPool -> Text -> Int64 -> IO [ClassifierItem]
getClassifierByParent pool table parent = do
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " WHERE parent_id = ?"
  rows <- runDb pool $ rawSql sql [PersistInt64 parent] :: IO [Single PersistValue]
  return $ map (parseRow . (\(Single v) -> [v])) rows

getOksmAll = getAllClassifiers "oksm"
getOksmById = getClassifierById "oksm"
getOksmByCode = getClassifierByCode "oksm"
getOkvAll = getAllClassifiers "okv"
getOkvById = getClassifierById "okv"
getOkvByCode = getClassifierByCode "okv"
getOkeiAll = getAllClassifiers "okei"
getOkeiById = getClassifierById "okei"
getOkeiByCode = getClassifierByCode "okei"
getOkpd2All = getAllClassifiers "okpd2"
getOkpd2ById = getClassifierById "okpd2"
getOkpd2ByCode = getClassifierByCode "okpd2"
getOkpd2ByParent = getClassifierByParent "okpd2"
getOkved2All = getAllClassifiers "okved2"
getOkved2ById = getClassifierById "okved2"
getOkved2ByCode = getClassifierByCode "okved2"
getOkved2ByParent = getClassifierByParent "okved2"
getTnvedAll = getAllClassifiers "tnved"
getTnvedById = getClassifierById "tnved"
getTnvedByCode = getClassifierByCode "tnved"
getTnvedByParent = getClassifierByParent "tnved"
getOkatoAll = getAllClassifiers "okato"
getOkatoById = getClassifierById "okato"
getOkatoByCode = getClassifierByCode "okato"
getOkatoByParent = getClassifierByParent "okato"
getOktmoAll = getAllClassifiers "oktmo"
getOktmoById = getClassifierById "oktmo"
getOktmoByCode = getClassifierByCode "oktmo"
getOktmoByParent = getClassifierByParent "oktmo"
