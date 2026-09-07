{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
-- | CRM Types - Core CRM domain types
module CRM.Types
  ( Deal(..)
  , DealInput(..)
  , DealStage(..)
  , Activity(..)
  , ActivityInput(..)
  , ActivityType(..)
  , Contact(..)
  , ContactInput(..)
  , Company(..)
  , CompanyInput(..)
  , PipelineForecast(..)
  , DealStats(..)
  ) where

import Data.Text (Text)
import Data.Int (Int64)
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)

-- | Deal stage in the pipeline
data DealStage
  = Lead
  | Qualified
  | Proposal
  | Negotiation
  | Won
  | Lost
  deriving (Show, Eq, Generic, Read)

instance FromJSON DealStage
instance ToJSON DealStage

-- | Deal (sales opportunity)
data Deal = Deal
  { dealId :: !Int64
  , dealTitle :: !Text
  , dealDescription :: !(Maybe Text)
  , dealAmount :: !Double
  , dealCurrency :: !Text
  , dealStage :: !DealStage
  , dealProbability :: !Int  -- 0-100
  , dealContactId :: !(Maybe Int64)
  , dealCompanyId :: !(Maybe Int64)
  , dealOwnerId :: !(Maybe Int64)
  , dealExpectedCloseDate :: !(Maybe UTCTime)
  , dealActualCloseDate :: !(Maybe UTCTime)
  , dealCreatedAt :: !UTCTime
  , dealUpdatedAt :: !UTCTime
  } deriving (Show, Eq, Generic)

instance FromJSON Deal
instance ToJSON Deal

-- | Deal input for creation/update
data DealInput = DealInput
  { dealInputTitle :: !Text
  , dealInputDescription :: !(Maybe Text)
  , dealInputAmount :: !Double
  , dealInputCurrency :: !Text
  , dealInputStage :: !(Maybe DealStage)
  , dealInputProbability :: !(Maybe Int)
  , dealInputContactId :: !(Maybe Int64)
  , dealInputCompanyId :: !(Maybe Int64)
  , dealInputOwnerId :: !(Maybe Int64)
  , dealInputExpectedCloseDate :: !(Maybe UTCTime)
  } deriving (Show, Eq, Generic)

instance FromJSON DealInput
instance ToJSON DealInput

-- | Activity type
data ActivityType
  = Call
  | Email
  | Meeting
  | Task
  | Note
  | Demo
  | FollowUp
  deriving (Show, Eq, Generic, Read)

instance FromJSON ActivityType
instance ToJSON ActivityType

-- | Activity (interaction record)
data Activity = Activity
  { activityId :: !Int64
  , activityType :: !ActivityType
  , activitySubject :: !Text
  , activityDescription :: !(Maybe Text)
  , activityDealId :: !(Maybe Int64)
  , activityContactId :: !(Maybe Int64)
  , activityCompanyId :: !(Maybe Int64)
  , activityOwnerId :: !(Maybe Int64)
  , activityDueDate :: !(Maybe UTCTime)
  , activityCompletedAt :: !(Maybe UTCTime)
  , activityCreatedAt :: !UTCTime
  } deriving (Show, Eq, Generic)

instance FromJSON Activity
instance ToJSON Activity

-- | Activity input
data ActivityInput = ActivityInput
  { activityInputType :: !ActivityType
  , activityInputSubject :: !Text
  , activityInputDescription :: !(Maybe Text)
  , activityInputDealId :: !(Maybe Int64)
  , activityInputContactId :: !(Maybe Int64)
  , activityInputCompanyId :: !(Maybe Int64)
  , activityInputOwnerId :: !(Maybe Int64)
  , activityInputDueDate :: !(Maybe UTCTime)
  } deriving (Show, Eq, Generic)

instance FromJSON ActivityInput
instance ToJSON ActivityInput

-- | Contact (person in CRM)
data Contact = Contact
  { contactId :: !Int64
  , contactFirstName :: !Text
  , contactLastName :: !(Maybe Text)
  , contactEmail :: !(Maybe Text)
  , contactPhone :: !(Maybe Text)
  , contactCompanyId :: !(Maybe Int64)
  , contactTitle :: !(Maybe Text)
  , contactCreatedAt :: !UTCTime
  } deriving (Show, Eq, Generic)

instance FromJSON Contact
instance ToJSON Contact

-- | Contact input
data ContactInput = ContactInput
  { contactInputFirstName :: !Text
  , contactInputLastName :: !(Maybe Text)
  , contactInputEmail :: !(Maybe Text)
  , contactInputPhone :: !(Maybe Text)
  , contactInputCompanyId :: !(Maybe Int64)
  , contactInputTitle :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON ContactInput
instance ToJSON ContactInput

-- | Company (organization in CRM)
data Company = Company
  { companyId :: !Int64
  , companyName :: !Text
  , companyIndustry :: !(Maybe Text)
  , companyWebsite :: !(Maybe Text)
  , companyPhone :: !(Maybe Text)
  , companyEmail :: !(Maybe Text)
  , companyAddress :: !(Maybe Text)
  , companyCreatedAt :: !UTCTime
  } deriving (Show, Eq, Generic)

instance FromJSON Company
instance ToJSON Company

-- | Company input
data CompanyInput = CompanyInput
  { companyInputName :: !Text
  , companyInputIndustry :: !(Maybe Text)
  , companyInputWebsite :: !(Maybe Text)
  , companyInputPhone :: !(Maybe Text)
  , companyInputEmail :: !(Maybe Text)
  , companyInputAddress :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance FromJSON CompanyInput
instance ToJSON CompanyInput

-- | Pipeline forecast
data PipelineForecast = PipelineForecast
  { forecastTotalValue :: !Double
  , forecastWeightedValue :: !Double
  , forecastDealCount :: !Int
  , forecastByStage :: [(DealStage, Double, Int)]
  } deriving (Show, Eq, Generic)

instance FromJSON PipelineForecast
instance ToJSON PipelineForecast

-- | Deal statistics
data DealStats = DealStats
  { statsTotalDeals :: !Int
  , statsOpenDeals :: !Int
  , statsWonDeals :: !Int
  , statsLostDeals :: !Int
  , statsTotalValue :: !Double
  , statsWonValue :: !Double
  , statsConversionRate :: !Double
  } deriving (Show, Eq, Generic)

instance FromJSON DealStats
instance ToJSON DealStats
