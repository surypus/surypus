
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeApplications #-}

module Surypus.API.BillTemplates
  ( listTemplates
  , saveTemplate
  , deleteTemplate
  , BillTemplateInfo(..)
  ) where

import Control.Monad.IO.Class (liftIO)
import DAL.ORMPool (ConnectionPool)
import DAL.Types (MutationResult(..), QueryResult(..))
import Data.Aeson (ToJSON, FromJSON, decode, encode)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as LE
import GHC.Generics (Generic)
import Database.Persist.Sql (runSqlPool, toSqlKey)
import qualified Database.Persist as P
import Database.Esqueleto.Experimental
import Surypus.DB.Schema (ReportTemplateEntity(..), ReportTemplateEntityId, ReportTemplateEntityReportType)
import DAL.Conversion
import Database.Persist.Sql (fromSqlKey, Key)

keyToInt :: Key a -> Int64
keyToInt = fromIntegral . fromSqlKey

data BillTemplateInfo = BillTemplateInfo
  { btiId :: Int64
  , btiName :: Text
  , btiContent :: Text
  } deriving (Show, Eq, Generic)
instance ToJSON BillTemplateInfo
instance FromJSON BillTemplateInfo

listTemplates :: ConnectionPool -> IO (QueryResult [BillTemplateInfo])
listTemplates pool = do
  entities <- liftIO $ runSqlPool
    (select $ do
        r <- from $ table @ReportTemplateEntity
        where_ $ r ^. ReportTemplateEntityReportType ==. val 10
        orderBy [asc $ r ^. ReportTemplateEntityId]
        return r
    ) pool
  return $ QuerySuccess (map templateFromEntity entities)
  where
    templateFromEntity (P.Entity rid e) = BillTemplateInfo
      (keyToInt rid)
      (reportTemplateEntityName e)
      (reportTemplateEntityContent e)

saveTemplate :: ConnectionPool -> Text -> Text -> IO (QueryResult MutationResult)
saveTemplate pool name content = do
  let code = "BT_" <> T.take 50 (T.filter (/= ' ') name)
  key <- liftIO $ runSqlPool (P.insert $ ReportTemplateEntity
    { reportTemplateEntityCode = code
    , reportTemplateEntityName = name
    , reportTemplateEntityReportType = 10
    , reportTemplateEntityContent = content
    , reportTemplateEntityFormat = "json"
    }) pool
  return $ QuerySuccess (MutationResult True (Just $ keyToInt key) "Template saved")

deleteTemplate :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteTemplate pool tid = do
  _ <- liftIO $ runSqlPool (P.delete (toSqlKey tid :: P.Key ReportTemplateEntity)) pool
  return $ QuerySuccess ()
