{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.CRM (
    Deal (..),
    DealInput (..),
    DealStage (..),
    Activity (..),
    ActivityInput (..),
    PipelineForecast (..),
    listDeals,
    createDeal,
    getDeal,
    updateDeal,
    deleteDeal,
    updateDealStage,
    getPipelineForecast,
    listActivities,
    createActivity,
    Contact (..),
    ContactInput (..),
    listContacts,
    createContact,
    getContact,
    updateContact,
    deleteContact,
    searchContacts,
    Company (..),
    CompanyInput (..),
    listCompanies,
    createCompany,
    getCompany,
    updateCompany,
    deleteCompany,
    searchCompanies,
    PipelineStage (..),
    StageRule (..),
    StageTransition (..),
    listPipelineStages,
    getStageRules,
    refreshPipelineForecast,
    getStageHistory,
) where

import Control.Monad.IO.Class (liftIO)
import DAL.Types (QueryResult (..))
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Sql (ConnectionPool, PersistValue (..), rawExecute, rawSql, runSqlPool, Single (..))
import GHC.Generics (Generic)

data DealStage = DealStage
    { dsId :: !Text
    , dsName :: !Text
    , dsOrder :: !Int
    , dsProbability :: !Double
    }
    deriving (Show, Eq, Generic)
instance ToJSON DealStage

data Deal = Deal
    { dealId :: !Text
    , dealName :: !Text
    , dealValue :: !Double
    , dealStage :: !Text
    , dealPerson :: !(Maybe Text)
    , dealCompany :: !(Maybe Text)
    , dealExpectedClose :: !(Maybe Text)
    , dealPriority :: !Text
    , dealProbability :: !Double
    , dealActive :: !Bool
    }
    deriving (Show, Eq, Generic)
instance ToJSON Deal

data DealInput = DealInput
    { diName :: !Text
    , diValue :: !Double
    , diStageId :: !Text
    , diPersonId :: !(Maybe Text)
    , diCompanyId :: !(Maybe Text)
    , diExpectedClose :: !(Maybe Text)
    , diPriority :: !Text
    }
    deriving (Show, Eq, Generic)
instance ToJSON DealInput
instance FromJSON DealInput

data Activity = Activity
    { actId :: !Text
    , actDealId :: !Text
    , actType :: !Text
    , actSubject :: !Text
    , actDescription :: !(Maybe Text)
    , actDate :: !Text
    , actCompleted :: !Bool
    }
    deriving (Show, Eq, Generic)
instance ToJSON Activity

data ActivityInput = ActivityInput
    { aiDealId :: !Text
    , aiType :: !Text
    , aiSubject :: !Text
    , aiDescription :: !(Maybe Text)
    }
    deriving (Show, Eq, Generic)
instance ToJSON ActivityInput
instance FromJSON ActivityInput

data PipelineForecast = PipelineForecast
    { pfStage :: !Text
    , pfDealCount :: !Int64
    , pfPipelineValue :: !Double
    , pfWeightedForecast :: !Double
    }
    deriving (Show, Eq, Generic)
instance ToJSON PipelineForecast

data Contact = Contact
    { cId :: !Text
    , cName :: !Text
    , cEmail :: !(Maybe Text)
    }
    deriving (Show, Eq, Generic)
instance ToJSON Contact
instance FromJSON Contact

data ContactInput = ContactInput
    { ciName :: !Text
    , ciEmail :: !(Maybe Text)
    }
    deriving (Show, Eq, Generic)
instance ToJSON ContactInput
instance FromJSON ContactInput

data Company = Company
    { compId :: !Text
    , compName :: !Text
    }
    deriving (Show, Eq, Generic)
instance ToJSON Company
instance FromJSON Company

data CompanyInput = CompanyInput
    { compName :: !Text
    }
    deriving (Show, Eq, Generic)
instance ToJSON CompanyInput
instance FromJSON CompanyInput

data PipelineStage = PipelineStage
    { psId :: !Text
    , psName :: !Text
    , psProbability :: !Int
    }
    deriving (Show, Eq, Generic)
instance ToJSON PipelineStage
instance FromJSON PipelineStage

data StageRule = StageRule
    { srId :: !Text
    , srName :: !Text
    }
    deriving (Show, Eq, Generic)
instance ToJSON StageRule
instance FromJSON StageRule

data StageTransition = StageTransition
    { stId :: !Text
    , stFromStage :: !Text
    , stToStage :: !Text
    }
    deriving (Show, Eq, Generic)
instance ToJSON StageTransition
instance FromJSON StageTransition

-- Row parsers
dealFromRow :: (Single Text, Single Text, Single Double, Single Text, Single (Maybe Text), Single (Maybe Text), Single (Maybe Text), Single Text, Single Double, Single Bool) -> Deal
dealFromRow (Single i, Single n, Single v, Single s, Single p, Single c, Single e, Single pr, Single pb, Single a) =
    Deal i n v s p c e pr pb a

forecastFromRow :: (Single Text, Single Int64, Single Double, Single Double) -> PipelineForecast
forecastFromRow (Single s, Single c, Single v, Single w) = PipelineForecast s c v w

activityFromRow :: (Single Text, Single Text, Single Text, Single Text, Single (Maybe Text), Single Text, Single Bool) -> Activity
activityFromRow (Single i, Single d, Single t, Single s, Single desc, Single dt, Single c) = Activity i d t s desc dt c

contactFromRow :: (Single Text, Single Text, Single (Maybe Text)) -> Contact
contactFromRow (Single i, Single n, Single e) = Contact i n e

companyFromRow :: (Single Text, Single Text) -> Company
companyFromRow (Single i, Single n) = Company i n

stageFromRow :: (Single Text, Single Text, Single Int) -> PipelineStage
stageFromRow (Single i, Single n, Single p) = PipelineStage i n p

ruleFromRow :: (Single Text, Single Text) -> StageRule
ruleFromRow (Single i, Single n) = StageRule i n

transitionFromRow :: (Single Text, Single Text, Single Text) -> StageTransition
transitionFromRow (Single i, Single f, Single t) = StageTransition i f t

-- Deal endpoints
listDeals :: ConnectionPool -> IO (QueryResult [Deal])
listDeals pool = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT d.id, d.deal_name, d.deal_value, s.stage_name, \
                \  p.full_name, co.company_name, \
                \  d.expected_close_date::TEXT, d.priority, d.probability, d.is_active \
                \FROM crm_deals d \
                \LEFT JOIN crm_pipeline_stages s ON d.stage_id = s.id \
                \LEFT JOIN persons p ON d.person_id = p.id \
                \LEFT JOIN companies co ON d.company_id = co.id \
                \ORDER BY d.created_at DESC" []) pool
    return $ QuerySuccess (map dealFromRow rows)

createDeal :: ConnectionPool -> DealInput -> IO (QueryResult Deal)
createDeal pool input = do
    let sql = "INSERT INTO crm_deals (tenant_id, deal_name, deal_value, stage_id, \
              \  person_id, company_id, expected_close_date, priority, probability) \
              \VALUES ('00000000-0000-0000-0000-000000000000', ?, ?, ?::UUID, ?::UUID, ?::UUID, ?::DATE, ?, \
              \  (SELECT stage_probability FROM crm_pipeline_stages WHERE id = ?::UUID)) \
              \RETURNING id, ?, ?, (SELECT stage_name FROM crm_pipeline_stages WHERE id = ?::UUID), \
              \  NULL::TEXT, NULL::TEXT, ?::TEXT, ?, \
              \  (SELECT stage_probability FROM crm_pipeline_stages WHERE id = ?::UUID), TRUE"
    let params = [ PersistText (diName input), PersistDouble (diValue input)
                 , PersistText (diStageId input)
                 , case diPersonId input of { Just p -> PersistText p; Nothing -> PersistNull }
                 , case diCompanyId input of { Just c -> PersistText c; Nothing -> PersistNull }
                 , case diExpectedClose input of { Just d -> PersistText d; Nothing -> PersistNull }
                 , PersistText (diPriority input), PersistText (diStageId input)
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (dealFromRow row)
        _ -> return $ QueryError "Failed to create deal"

getDeal :: ConnectionPool -> Text -> IO (QueryResult Deal)
getDeal pool did = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT d.id, d.deal_name, d.deal_value, s.stage_name, \
                \  p.full_name, co.company_name, \
                \  d.expected_close_date::TEXT, d.priority, d.probability, d.is_active \
                \FROM crm_deals d \
                \LEFT JOIN crm_pipeline_stages s ON d.stage_id = s.id \
                \LEFT JOIN persons p ON d.person_id = p.id \
                \LEFT JOIN companies co ON d.company_id = co.id \
                \WHERE d.id = ?::UUID" [PersistText did]) pool
    case rows of
        (row:_) -> return $ QuerySuccess (dealFromRow row)
        _ -> return $ QueryError "Not Found"

updateDeal :: ConnectionPool -> Text -> DealInput -> IO (QueryResult Deal)
updateDeal pool did input = do
    let sql = "UPDATE crm_deals SET \
              \  deal_name = ?, deal_value = ?, stage_id = ?::UUID, \
              \  person_id = ?::UUID, company_id = ?::UUID, \
              \  expected_close_date = ?::DATE, priority = ?, \
              \  probability = (SELECT stage_probability FROM crm_pipeline_stages WHERE id = ?::UUID), \
              \  updated_at = NOW() \
              \WHERE id = ?::UUID \
              \RETURNING id, ?, ?, \
              \  (SELECT stage_name FROM crm_pipeline_stages WHERE id = ?::UUID), \
              \  NULL::TEXT, NULL::TEXT, ?::TEXT, ?, \
              \  (SELECT stage_probability FROM crm_pipeline_stages WHERE id = ?::UUID), TRUE"
    let params = [ PersistText (diName input), PersistDouble (diValue input)
                 , PersistText (diStageId input)
                 , case diPersonId input of { Just p -> PersistText p; Nothing -> PersistNull }
                 , case diCompanyId input of { Just c -> PersistText c; Nothing -> PersistNull }
                 , case diExpectedClose input of { Just d -> PersistText d; Nothing -> PersistNull }
                 , PersistText (diPriority input), PersistText (diStageId input)
                 , PersistText did
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (dealFromRow row)
        _ -> return $ QueryError "Not Found"

deleteDeal :: ConnectionPool -> Text -> IO (QueryResult ())
deleteDeal pool did = do
    liftIO $ runSqlPool (rawExecute "DELETE FROM crm_deals WHERE id = ?::UUID" [PersistText did]) pool
    return $ QuerySuccess ()

updateDealStage :: ConnectionPool -> Text -> Text -> IO (QueryResult Deal)
updateDealStage pool did newStageId = do
    let sql = "UPDATE crm_deals SET stage_id = ?::UUID, \
              \  probability = (SELECT stage_probability FROM crm_pipeline_stages WHERE id = ?::UUID), \
              \  updated_at = NOW() \
              \WHERE id = ?::UUID \
              \RETURNING id, deal_name, deal_value, \
              \  (SELECT stage_name FROM crm_pipeline_stages WHERE id = ?::UUID), \
              \  NULL::TEXT, NULL::TEXT, expected_close_date::TEXT, priority, \
              \  (SELECT stage_probability FROM crm_pipeline_stages WHERE id = ?::UUID), is_active"
    let params = [PersistText newStageId, PersistText newStageId, PersistText did
                 , PersistText newStageId, PersistText newStageId
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (dealFromRow row)
        _ -> return $ QueryError "Not Found"

getPipelineForecast :: ConnectionPool -> IO (QueryResult [PipelineForecast])
getPipelineForecast pool = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT stage_name, deal_count, pipeline_value, weighted_forecast \
                \FROM mv_crm_pipeline_forecast ORDER BY stage_order" []) pool
    return $ QuerySuccess (map forecastFromRow rows)

listActivities :: ConnectionPool -> Text -> IO (QueryResult [Activity])
listActivities pool dealId = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT id, deal_id, activity_type, subject, \
                \  description, activity_date::TEXT, is_completed \
                \FROM crm_activities WHERE deal_id = ?::UUID ORDER BY activity_date DESC"
                [PersistText dealId]) pool
    return $ QuerySuccess (map activityFromRow rows)

createActivity :: ConnectionPool -> ActivityInput -> IO (QueryResult Activity)
createActivity pool input = do
    let sql = "INSERT INTO crm_activities (deal_id, activity_type, subject, description, activity_date) \
              \VALUES (?::UUID, ?, ?, ?, NOW()) \
              \RETURNING id, deal_id, activity_type, subject, \
              \  description, activity_date::TEXT, is_completed"
    let params = [ PersistText (aiDealId input), PersistText (aiType input)
                 , PersistText (aiSubject input)
                 , case aiDescription input of { Just d -> PersistText d; Nothing -> PersistNull }
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (activityFromRow row)
        _ -> return $ QueryError "Failed to create activity"

-- Contact endpoints
listContacts :: ConnectionPool -> IO (QueryResult [Contact])
listContacts pool = do
    rows <- liftIO $ runSqlPool (rawSql "SELECT id, name, email FROM crm_contacts ORDER BY name" []) pool
    return $ QuerySuccess (map contactFromRow rows)

createContact :: ConnectionPool -> ContactInput -> IO (QueryResult Contact)
createContact pool input = do
    let sql = "INSERT INTO crm_contacts (name, email) VALUES (?, ?) RETURNING id, name, email"
    let params = [ PersistText (ciName input)
                 , case ciEmail input of { Just e -> PersistText e; Nothing -> PersistNull }
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (contactFromRow row)
        _ -> return $ QueryError "Failed to create contact"

getContact :: ConnectionPool -> Text -> IO (QueryResult Contact)
getContact pool cid = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT id, name, email FROM crm_contacts WHERE id = ?::UUID" [PersistText cid]) pool
    case rows of
        (row:_) -> return $ QuerySuccess (contactFromRow row)
        _ -> return $ QueryError "Not Found"

updateContact :: ConnectionPool -> Text -> ContactInput -> IO (QueryResult Contact)
updateContact pool cid input = do
    let sql = "UPDATE crm_contacts SET name = ?, email = ? WHERE id = ?::UUID RETURNING id, name, email"
    let params = [ PersistText (ciName input)
                 , case ciEmail input of { Just e -> PersistText e; Nothing -> PersistNull }
                 , PersistText cid
                 ]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (contactFromRow row)
        _ -> return $ QueryError "Not Found"

deleteContact :: ConnectionPool -> Text -> IO (QueryResult ())
deleteContact pool cid = do
    liftIO $ runSqlPool (rawExecute "DELETE FROM crm_contacts WHERE id = ?::UUID" [PersistText cid]) pool
    return $ QuerySuccess ()

searchContacts :: ConnectionPool -> Text -> IO (QueryResult [Contact])
searchContacts pool query = do
    let searchPattern = "%" <> query <> "%"
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT id, name, email FROM crm_contacts \
                \WHERE name ILIKE ? OR email ILIKE ? ORDER BY name"
                [PersistText searchPattern, PersistText searchPattern]) pool
    return $ QuerySuccess (map contactFromRow rows)

-- Company endpoints
listCompanies :: ConnectionPool -> IO (QueryResult [Company])
listCompanies pool = do
    rows <- liftIO $ runSqlPool (rawSql "SELECT id, company_name FROM crm_companies ORDER BY company_name" []) pool
    return $ QuerySuccess (map companyFromRow rows)

createCompany :: ConnectionPool -> CompanyInput -> IO (QueryResult Company)
createCompany pool (CompanyInput cname) = do
    rows <- liftIO $ runSqlPool
        (rawSql "INSERT INTO crm_companies (company_name) VALUES (?) RETURNING id, company_name" [PersistText cname]) pool
    case rows of
        (row:_) -> return $ QuerySuccess (companyFromRow row)
        _ -> return $ QueryError "Failed to create company"

getCompany :: ConnectionPool -> Text -> IO (QueryResult Company)
getCompany pool cid = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT id, company_name FROM crm_companies WHERE id = ?::UUID" [PersistText cid]) pool
    case rows of
        (row:_) -> return $ QuerySuccess (companyFromRow row)
        _ -> return $ QueryError "Not Found"

updateCompany :: ConnectionPool -> Text -> CompanyInput -> IO (QueryResult Company)
updateCompany pool cid (CompanyInput cname) = do
    let sql = "UPDATE crm_companies SET company_name = ? WHERE id = ?::UUID RETURNING id, company_name"
    let params = [PersistText cname, PersistText cid]
    rows <- liftIO $ runSqlPool (rawSql sql params) pool
    case rows of
        (row:_) -> return $ QuerySuccess (companyFromRow row)
        _ -> return $ QueryError "Not Found"

deleteCompany :: ConnectionPool -> Text -> IO (QueryResult ())
deleteCompany pool cid = do
    liftIO $ runSqlPool (rawExecute "DELETE FROM crm_companies WHERE id = ?::UUID" [PersistText cid]) pool
    return $ QuerySuccess ()

searchCompanies :: ConnectionPool -> Text -> IO (QueryResult [Company])
searchCompanies pool query = do
    let searchPattern = "%" <> query <> "%"
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT id, company_name FROM crm_companies \
                \WHERE company_name ILIKE ? ORDER BY company_name" [PersistText searchPattern]) pool
    return $ QuerySuccess (map companyFromRow rows)

-- Pipeline endpoints
listPipelineStages :: ConnectionPool -> IO (QueryResult [PipelineStage])
listPipelineStages pool = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT id, stage_name, stage_probability \
                \FROM crm_pipeline_stages ORDER BY stage_order" []) pool
    return $ QuerySuccess (map stageFromRow rows)

getStageRules :: ConnectionPool -> Text -> IO (QueryResult [StageRule])
getStageRules pool stageId = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT sr.id, sr.name FROM crm_stage_rules sr \
                \WHERE sr.from_stage_id = ?::UUID OR sr.to_stage_id = ?::UUID \
                \ORDER BY sr.name" [PersistText stageId, PersistText stageId]) pool
    return $ QuerySuccess (map ruleFromRow rows)

refreshPipelineForecast :: ConnectionPool -> IO (QueryResult ())
refreshPipelineForecast pool = do
    liftIO $ runSqlPool (rawExecute "REFRESH MATERIALIZED VIEW mv_crm_pipeline_forecast" []) pool
    return $ QuerySuccess ()

getStageHistory :: ConnectionPool -> Text -> IO (QueryResult [StageTransition])
getStageHistory pool dealId = do
    rows <- liftIO $ runSqlPool
        (rawSql "SELECT sh.id, \
                \  COALESCE((SELECT stage_name FROM crm_pipeline_stages WHERE id = sh.from_stage_id), ''), \
                \  COALESCE((SELECT stage_name FROM crm_pipeline_stages WHERE id = sh.to_stage_id), '') \
                \FROM crm_stage_history sh \
                \WHERE sh.deal_id = ?::UUID ORDER BY sh.changed_at DESC" [PersistText dealId]) pool
    return $ QuerySuccess (map transitionFromRow rows)
