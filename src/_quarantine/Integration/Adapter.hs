{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE AllowAmbiguousTypes #-}

-- | Integration Adapter Pattern - Typeclass for external system integrations
module Integration.Adapter
  ( IntegrationAdapter(..)
  , AdapterConfig(..)
  , AdapterResult(..)
  , BankStatementAdapter(..)
  , MarketplaceAdapter(..)
  , PaymentGatewayAdapter(..)
  , createBankStatementAdapter
  , createMarketplaceAdapter
  , createPaymentGatewayAdapter
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, Value)
import GHC.Generics (Generic)
import Data.Time (UTCTime, getCurrentTime)
import DAL.ORMPool (ConnectionPool)
import DAL.Types (QueryResult(..))

-- ============================================================================
-- ADAPTER CONFIGURATION
-- ============================================================================

-- | Adapter configuration stored in integration_config table
data AdapterConfig = AdapterConfig
  { acTenantId :: Text
  , acAdapterType :: Text
  , acCredentials :: Value
  , acEnabled :: Bool
  , acSettings :: Value
  } deriving (Show, Eq, Generic)

instance ToJSON AdapterConfig
instance FromJSON AdapterConfig

-- ============================================================================
-- ADAPTER TYPECLASS
-- ============================================================================

-- | Generic adapter interface for external system integrations
class IntegrationAdapter a where
  -- | Establish connection to external system
  connect :: a -> IO (Either Text Connection)
  
  -- | Fetch data from external system
  fetch :: Connection -> a -> IO (Either Text [ExternalData])
  
  -- | Transform external data to domain entities
  transform :: a -> [ExternalData] -> [DomainEntity]
  
  -- | Persist domain entities to database
  persist :: ConnectionPool -> [DomainEntity] -> IO (Either Text ())
  
  -- | Get adapter type identifier
  adapterType :: a -> Text

-- ============================================================================
-- GENERIC TYPES
-- ============================================================================

-- | Connection handle (type-safe wrapper)
data Connection = Connection
  { connId :: Text
  , connEstablishedAt :: UTCTime
  , connAdapterType :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON Connection
instance FromJSON Connection

-- | External data from adapter
data ExternalData = ExternalData
  { dataId :: Text
  , dataType :: Text
  , dataContent :: Value
  , dataTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

instance ToJSON ExternalData
instance FromJSON ExternalData

-- | Domain entity after transformation
data DomainEntity = DomainEntity
  { deEntityId :: Text
  , deEntityType :: Text
  , deData :: Value
  } deriving (Show, Eq, Generic)

instance ToJSON DomainEntity
instance FromJSON DomainEntity

-- | Result from adapter operation
data AdapterResult = AdapterResult
  { arSuccess :: Bool
  , arMessage :: Text
  , arProcessedCount :: Int
  , arErrors :: [Text]
  } deriving (Show, Eq, Generic)

instance ToJSON AdapterResult
instance FromJSON AdapterResult

-- ============================================================================
-- BANK STATEMENT ADAPTER
-- ============================================================================

-- | Bank statement adapter configuration
data BankStatementAdapter = BankStatementAdapter
  { bsaConfig :: AdapterConfig
  , bsaFormat :: Text  -- "OFX" or "ISO20022"
  } deriving (Show, Eq, Generic)

instance ToJSON BankStatementAdapter
instance FromJSON BankStatementAdapter

instance IntegrationAdapter BankStatementAdapter where
  connect adapter = do
    -- Bank statement adapters don't require live connections
    -- Connection is virtual for consistency with adapter pattern
    now <- getCurrentTime
    return $ Right $ Connection
      { connId = "virtual-" <> T.pack (show (acTenantId (bsaConfig adapter)))
      , connEstablishedAt = now
      , connAdapterType = "BankStatement"
      }
  
  fetch _conn adapter = do
    -- Bank statement data is uploaded via API, not fetched
    -- This is a placeholder for future direct bank API integration
    return $ Left "Bank statement data must be uploaded via API"
  
  transform adapter externalData = do
    -- Transform external data to domain entities
    map (toDomainEntity adapter) externalData
  
  persist pool entities = do
    -- Persist domain entities to database
    mapM_ (persistEntity pool) entities
    return $ Right ()
  
  adapterType _ = "BankStatement"

-- | Create bank statement adapter from config
createBankStatementAdapter :: AdapterConfig -> Text -> BankStatementAdapter
createBankStatementAdapter config format = BankStatementAdapter
  { bsaConfig = config
  , bsaFormat = format
  }

-- | Transform external data to domain entity for bank statement
toDomainEntity :: BankStatementAdapter -> ExternalData -> DomainEntity
toDomainEntity adapter extData = DomainEntity
  { deEntityId = dataId extData
  , deEntityType = "BankTransaction"
  , deData = dataContent extData
  }

-- | Persist domain entity to database
persistEntity :: ConnectionPool -> DomainEntity -> IO ()
persistEntity pool entity = do
  -- Stub implementation - would persist to appropriate table based on entity type
  return ()

-- ============================================================================
-- MARKETPLACE ADAPTER
-- ============================================================================

-- | Marketplace adapter configuration
data MarketplaceAdapter = MarketplaceAdapter
  { mpaConfig :: AdapterConfig
  , mpaMarketplaceType :: Text  -- "Amazon", "eBay", etc.
  , mpaApiEndpoint :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON MarketplaceAdapter
instance FromJSON MarketplaceAdapter

instance IntegrationAdapter MarketplaceAdapter where
  connect adapter = do
    -- Connect to marketplace API using credentials
    now <- getCurrentTime
    return $ Right $ Connection
      { connId = "marketplace-" <> T.pack (show (acTenantId (mpaConfig adapter)))
      , connEstablishedAt = now
      , connAdapterType = "Marketplace"
      }
  
  fetch conn adapter = do
    -- Fetch orders/products from marketplace API
    -- Placeholder for actual API integration
    return $ Right []
  
  transform adapter externalData = do
    -- Transform marketplace data to domain entities
    map (toMarketplaceEntity adapter) externalData
  
  persist pool entities = do
    -- Persist marketplace entities to database
    mapM_ (persistEntity pool) entities
    return $ Right ()
  
  adapterType _ = "Marketplace"

-- | Create marketplace adapter from config
createMarketplaceAdapter :: AdapterConfig -> Text -> Text -> MarketplaceAdapter
createMarketplaceAdapter config marketplaceType apiEndpoint = MarketplaceAdapter
  { mpaConfig = config
  , mpaMarketplaceType = marketplaceType
  , mpaApiEndpoint = apiEndpoint
  }

-- | Transform marketplace data to domain entity
toMarketplaceEntity :: MarketplaceAdapter -> ExternalData -> DomainEntity
toMarketplaceEntity adapter extData = DomainEntity
  { deEntityId = dataId extData
  , deEntityType = "MarketplaceOrder"
  , deData = dataContent extData
  }

-- ============================================================================
-- PAYMENT GATEWAY ADAPTER
-- ============================================================================

-- | Payment gateway adapter configuration
data PaymentGatewayAdapter = PaymentGatewayAdapter
  { pgaConfig :: AdapterConfig
  , pgaGatewayType :: Text  -- "Stripe", "PayPal", etc.
  , pgaApiEndpoint :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON PaymentGatewayAdapter
instance FromJSON PaymentGatewayAdapter

instance IntegrationAdapter PaymentGatewayAdapter where
  connect adapter = do
    -- Connect to payment gateway API using credentials
    now <- getCurrentTime
    return $ Right $ Connection
      { connId = "payment-" <> T.pack (show (acTenantId (pgaConfig adapter)))
      , connEstablishedAt = now
      , connAdapterType = "PaymentGateway"
      }
  
  fetch conn adapter = do
    -- Fetch transactions from payment gateway API
    -- Placeholder for actual API integration
    return $ Right []
  
  transform adapter externalData = do
    -- Transform payment data to domain entities
    map (toPaymentEntity adapter) externalData
  
  persist pool entities = do
    -- Persist payment entities to database
    mapM_ (persistEntity pool) entities
    return $ Right ()
  
  adapterType _ = "PaymentGateway"

-- | Create payment gateway adapter from config
createPaymentGatewayAdapter :: AdapterConfig -> Text -> Text -> PaymentGatewayAdapter
createPaymentGatewayAdapter config gatewayType apiEndpoint = PaymentGatewayAdapter
  { pgaConfig = config
  , pgaGatewayType = gatewayType
  , pgaApiEndpoint = apiEndpoint
  }

-- | Transform payment data to domain entity
toPaymentEntity :: PaymentGatewayAdapter -> ExternalData -> DomainEntity
toPaymentEntity adapter extData = DomainEntity
  { deEntityId = dataId extData
  , deEntityType = "PaymentTransaction"
  , deData = dataContent extData
  }
