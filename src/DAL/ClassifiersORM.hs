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

data ClassifierItem = ClassifierItem
  { classifierItemId :: !Int64
  , classifierItemCode :: !Text
  , classifierItemName :: !Text
  , classifierItemDescription :: !(Maybe Text)
  , classifierItemParentId :: !(Maybe Int64)
  } deriving (Show, Eq)

emptyClassifier :: ClassifierItem
emptyClassifier = ClassifierItem 0 T.empty T.empty Nothing Nothing

getOksmAll :: IO [ClassifierItem]
getOksmAll = return []
getOksmById :: Int64 -> IO (Maybe ClassifierItem)
getOksmById _ = return Nothing
getOksmByCode :: Text -> IO (Maybe ClassifierItem)
getOksmByCode _ = return Nothing
getOkvAll :: IO [ClassifierItem]
getOkvAll = return []
getOkvById :: Int64 -> IO (Maybe ClassifierItem)
getOkvById _ = return Nothing
getOkvByCode :: Text -> IO (Maybe ClassifierItem)
getOkvByCode _ = return Nothing
getOkeiAll :: IO [ClassifierItem]
getOkeiAll = return []
getOkeiById :: Int64 -> IO (Maybe ClassifierItem)
getOkeiById _ = return Nothing
getOkeiByCode :: Text -> IO (Maybe ClassifierItem)
getOkeiByCode _ = return Nothing
getOkpd2All :: IO [ClassifierItem]
getOkpd2All = return []
getOkpd2ById :: Int64 -> IO (Maybe ClassifierItem)
getOkpd2ById _ = return Nothing
getOkpd2ByCode :: Text -> IO (Maybe ClassifierItem)
getOkpd2ByCode _ = return Nothing
getOkpd2ByParent :: Int64 -> IO [ClassifierItem]
getOkpd2ByParent _ = return []
getOkved2All :: IO [ClassifierItem]
getOkved2All = return []
getOkved2ById :: Int64 -> IO (Maybe ClassifierItem)
getOkved2ById _ = return Nothing
getOkved2ByCode :: Text -> IO (Maybe ClassifierItem)
getOkved2ByCode _ = return Nothing
getOkved2ByParent :: Int64 -> IO [ClassifierItem]
getOkved2ByParent _ = return []
getTnvedAll :: IO [ClassifierItem]
getTnvedAll = return []
getTnvedById :: Int64 -> IO (Maybe ClassifierItem)
getTnvedById _ = return Nothing
getTnvedByCode :: Text -> IO (Maybe ClassifierItem)
getTnvedByCode _ = return Nothing
getTnvedByParent :: Int64 -> IO [ClassifierItem]
getTnvedByParent _ = return []
getOkatoAll :: IO [ClassifierItem]
getOkatoAll = return []
getOkatoById :: Int64 -> IO (Maybe ClassifierItem)
getOkatoById _ = return Nothing
getOkatoByCode :: Text -> IO (Maybe ClassifierItem)
getOkatoByCode _ = return Nothing
getOkatoByParent :: Int64 -> IO [ClassifierItem]
getOkatoByParent _ = return []
getOktmoAll :: IO [ClassifierItem]
getOktmoAll = return []
getOktmoById :: Int64 -> IO (Maybe ClassifierItem)
getOktmoById _ = return Nothing
getOktmoByCode :: Text -> IO (Maybe ClassifierItem)
getOktmoByCode _ = return Nothing
getOktmoByParent :: Int64 -> IO [ClassifierItem]
getOktmoByParent _ = return []
