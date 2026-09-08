-- | DAL ClassifiersORM - raw SQL queries for classifiers
module DAL.ClassifiersORM
  ( -- * OKSM
    getOksmAll
  , getOksmById
  , getOksmByCode
  , -- * OKV
    getOkvAll
  , getOkvById
  , getOkvByCode
  , -- * OKEI
    getOkeiAll
  , getOkeiById
  , getOkeiByCode
  , -- * OKPD2
    getOkpd2All
  , getOkpd2ById
  , getOkpd2ByCode
  , getOkpd2ByParent
  , -- * OKVED2
    getOkved2All
  , getOkved2ById
  , getOkved2ByCode
  , getOkved2ByParent
  , -- * TNVED
    getTnvedAll
  , getTnvedById
  , getTnvedByCode
  , getTnvedByParent
  , -- * OKATO
    getOkatoAll
  , getOkatoById
  , getOkatoByCode
  , getOkatoByParent
  , -- * OKTMO
    getOktmoAll
  , getOktmoById
  , getOktmoByCode
  , getOktmoByParent
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Sql (rawSql, Single(..), PersistValue(..))
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Database (ConnectionPool, runDb)

-- | Classifier item
data ClassifierItem = ClassifierItem
  { classifierItemId :: !Int64
  , classifierItemCode :: !Text
  , classifierItemName :: !Text
  , classifierItemDescription :: !(Maybe Text)
  , classifierItemParentId :: !(Maybe Int64)
  } deriving (Show, Eq)

-- | Extract Int64 from PersistValue
persistToInt64 :: PersistValue -> Int64
persistToInt64 (PersistInt64 n) = n
persistToInt64 (PersistDouble n) = round n
persistToInt64 _ = 0

-- | Extract Text from PersistValue
persistToText :: PersistValue -> Text
persistToText (PersistText t) = t
persistToText (PersistInt64 n) = T.pack $ show n
persistToText (PersistDouble n) = T.pack $ show n
persistToText _ = ""

-- | Extract Maybe Text from PersistValue
persistToMaybeText :: PersistValue -> Maybe Text
persistToMaybeText PersistNull = Nothing
persistToMaybeText v = Just $ persistToText v

-- | Extract Maybe Int64 from PersistValue
persistToMaybeInt64 :: PersistValue -> Maybe Int64
persistToMaybeInt64 PersistNull = Nothing
persistToMaybeInt64 (PersistInt64 n) = Just n
persistToMaybeInt64 (PersistDouble n) = Just $ round n
persistToMaybeInt64 _ = Nothing

-- | Parse classifier from database row
parseClassifier :: [Single PersistValue] -> ClassifierItem
parseClassifier (Single id' : Single code : Single name : Single desc : Single parent : _) =
  ClassifierItem
    { classifierItemId = persistToInt64 id'
    , classifierItemCode = persistToText code
    , classifierItemName = persistToText name
    , classifierItemDescription = persistToMaybeText desc
    , classifierItemParentId = persistToMaybeInt64 parent
    }
parseClassifier _ = ClassifierItem 0 "" "" Nothing Nothing

-- | Generic classifier query helpers
getAllClassifiers :: ConnectionPool -> Text -> IO [ClassifierItem]
getAllClassifiers pool table =
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " ORDER BY id"
  in do rows <- runDb pool $ rawSql sql []
        return $ map parseClassifier rows

getClassifierById :: ConnectionPool -> Text -> Int64 -> IO (Maybe ClassifierItem)
getClassifierById pool table id' =
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " WHERE id = ?"
  in do rows <- runDb pool $ rawSql sql [PersistInt64 id']
        case rows of
          (row : _) -> return $ Just $ parseClassifier row
          _ -> return Nothing

getClassifierByCode :: ConnectionPool -> Text -> Text -> IO (Maybe ClassifierItem)
getClassifierByCode pool table code =
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " WHERE code = ?"
  in do rows <- runDb pool $ rawSql sql [PersistText code]
        case rows of
          (row : _) -> return $ Just $ parseClassifier row
          _ -> return Nothing

getClassifierByParent :: ConnectionPool -> Text -> Int64 -> IO [ClassifierItem]
getClassifierByParent pool table parent =
  let sql = "SELECT id, code, name, description, parent_id FROM " <> T.unpack table <> " WHERE parent_id = ?"
  in do rows <- runDb pool $ rawSql sql [PersistInt64 parent]
        return $ map parseClassifier rows

-- OKSM
getOksmAll = getAllClassifiers "oksm"
getOksmById = getClassifierById "oksm"
getOksmByCode = getClassifierByCode "oksm"

-- OKV
getOkvAll = getAllClassifiers "okv"
getOkvById = getClassifierById "okv"
getOkvByCode = getClassifierByCode "okv"

-- OKEI
getOkeiAll = getAllClassifiers "okei"
getOkeiById = getClassifierById "okei"
getOkeiByCode = getClassifierByCode "okei"

-- OKPD2
getOkpd2All = getAllClassifiers "okpd2"
getOkpd2ById = getClassifierById "okpd2"
getOkpd2ByCode = getClassifierByCode "okpd2"
getOkpd2ByParent = getClassifierByParent "okpd2"

-- OKVED2
getOkved2All = getAllClassifiers "okved2"
getOkved2ById = getClassifierById "okved2"
getOkved2ByCode = getClassifierByCode "okved2"
getOkved2ByParent = getClassifierByParent "okved2"

-- TNVED
getTnvedAll = getAllClassifiers "tnved"
getTnvedById = getClassifierById "tnved"
getTnvedByCode = getClassifierByCode "tnved"
getTnvedByParent = getClassifierByParent "tnved"

-- OKATO
getOkatoAll = getAllClassifiers "okato"
getOkatoById = getClassifierById "okato"
getOkatoByCode = getClassifierByCode "okato"
getOkatoByParent = getClassifierByParent "okato"

-- OKTMO
getOktmoAll = getAllClassifiers "oktmo"
getOktmoById = getClassifierById "oktmo"
getOktmoByCode = getClassifierByCode "oktmo"
getOktmoByParent = getClassifierByParent "oktmo"
