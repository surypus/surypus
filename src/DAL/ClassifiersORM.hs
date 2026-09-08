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

persistToInt64 :: PersistValue -> Int64
persistToInt64 (PersistInt64 n) = n
persistToInt64 (PersistDouble n) = round n
persistToInt64 _ = 0

persistToText :: PersistValue -> Text
persistToText (PersistText t) = t
persistToText (PersistInt64 n) = T.pack $ show n
persistToText (PersistDouble n) = T.pack $ show n
persistToText _ = T.empty

persistToMaybeText :: PersistValue -> Maybe Text
persistToMaybeText PersistNull = Nothing
persistToMaybeText v = Just $ persistToText v

persistToMaybeInt64 :: PersistValue -> Maybe Int64
persistToMaybeInt64 PersistNull = Nothing
persistToMaybeInt64 (PersistInt64 n) = Just n
persistToMaybeInt64 (PersistDouble n) = Just $ round n
persistToMaybeInt64 _ = Nothing

parseClassifier :: PersistValue -> PersistValue -> PersistValue -> PersistValue -> PersistValue -> ClassifierItem
parseClassifier id' code name desc parent =
  ClassifierItem
    { classifierItemId = persistToInt64 id'
    , classifierItemCode = persistToText code
    , classifierItemName = persistToText name
    , classifierItemDescription = persistToMaybeText desc
    , classifierItemParentId = persistToMaybeInt64 parent
    }

getAllClassifiers :: ConnectionPool -> Text -> IO [ClassifierItem]
getAllClassifiers pool table = do
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " ORDER BY id"
  rows <- runDb pool $ rawSql sql [] :: IO [Single PersistValue]
  return $ map (\(Single a : Single b : Single c : Single d : Single e : _) -> parseClassifier a b c d e) rows

getClassifierById :: ConnectionPool -> Text -> Int64 -> IO (Maybe ClassifierItem)
getClassifierById pool table id' = do
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " WHERE id = ?"
  rows <- runDb pool $ rawSql sql [PersistInt64 id'] :: IO [Single PersistValue]
  case rows of
    (Single a : Single b : Single c : Single d : Single e : _) : _ -> return $ Just $ parseClassifier a b c d e
    _ -> return Nothing

getClassifierByCode :: ConnectionPool -> Text -> Text -> IO (Maybe ClassifierItem)
getClassifierByCode pool table code = do
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " WHERE code = ?"
  rows <- runDb pool $ rawSql sql [PersistText code] :: IO [Single PersistValue]
  case rows of
    (Single a : Single b : Single c : Single d : Single e : _) : _ -> return $ Just $ parseClassifier a b c d e
    _ -> return Nothing

getClassifierByParent :: ConnectionPool -> Text -> Int64 -> IO [ClassifierItem]
getClassifierByParent pool table parent = do
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " WHERE parent_id = ?"
  rows <- runDb pool $ rawSql sql [PersistInt64 parent] :: IO [Single PersistValue]
  return $ map (\(Single a : Single b : Single c : Single d : Single e : _) -> parseClassifier a b c d e) rows

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
