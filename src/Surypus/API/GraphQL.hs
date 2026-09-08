{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.GraphQL (GraphQLAPI, GraphQLQuery(..), GraphQLResponse(..), graphqlHandler) where

import Control.Monad.IO.Class (liftIO)
import DAL.Pool (ConnectionPool)
import Data.Aeson (Value(..), FromJSON, ToJSON, object, (.=), toJSON)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import Servant

import qualified Surypus.API.Bills as Bills
import qualified Surypus.API.Goods as Goods
import qualified Surypus.API.Persons as Persons
import qualified Surypus.API.Payment as Payments
import qualified Surypus.API.CRM as CRM
import qualified Surypus.API.Dashboard as Dashboard
import qualified Surypus.API.Orders as Orders
import Surypus (QueryResult(..))

data GraphQLQuery = GraphQLQuery
    { gqQuery     :: Text
    , gqVariables :: Maybe Value
    }
    deriving (Eq, Show, Generic, FromJSON, ToJSON)

data GraphQLResponse = GraphQLResponse
    { grData   :: Maybe Value
    , grErrors :: Maybe [Text]
    }
    deriving (Eq, Show, Generic, FromJSON, ToJSON)

type GraphQLAPI = ReqBody '[JSON] GraphQLQuery :> Post '[JSON] GraphQLResponse

graphqlHandler :: ConnectionPool -> GraphQLQuery -> Handler GraphQLResponse
graphqlHandler pool query = do
    let q = gqQuery query
    result <- liftIO $ resolveQuery pool q
    case result of
        Left err -> return $ GraphQLResponse Nothing (Just [err])
        Right val -> return $ GraphQLResponse (Just val) Nothing

resolveQuery :: ConnectionPool -> Text -> IO (Either Text Value)
resolveQuery pool q = do
    let clean = T.strip q
    if T.null clean
        then return $ Left "Empty query"
        else case T.words clean of
            (op:_) -> resolveOperation pool op
            []     -> return $ Left "Empty query"

resolveOperation :: ConnectionPool -> Text -> IO (Either Text Value)
resolveOperation pool op = 
    case op of
        "bills"         -> toJSON' <$> Bills.listBills pool
        "goods"         -> toJSON' <$> Goods.listGoods pool
        "persons"       -> toJSON' <$> Persons.listPersons pool Nothing Nothing Nothing Nothing Nothing
        "payments"      -> toJSON' <$> Payments.listPayments pool
        "deals"         -> toJSON' <$> CRM.listDeals pool
        "contacts"      -> toJSON' <$> CRM.listContacts pool
        "companies"     -> toJSON' <$> CRM.listCompanies pool
        "orders"        -> toJSON' <$> Orders.listOrders pool
        "dashboardKPI"  -> toJSON' <$> Dashboard.getDashboardKPI pool
        "pipelineForecast" -> toJSON' <$> CRM.getPipelineForecast pool
        "pipelineStages"   -> toJSON' <$> CRM.listPipelineStages pool
        _               -> return $ Right $ object ["message" .= ("Unknown operation: " <> op)]

toJSON' :: ToJSON a => QueryResult a -> Either Text Value
toJSON' (QuerySuccess a) = Right $ toJSON a
toJSON' (QueryError e)   = Left e
