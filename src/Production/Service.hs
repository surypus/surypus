-- | Production Service (Phase 1: stub)
module Production.Service
  ( TechCard(..)
  , TechLine(..)
  , createTechCard
  , createTechLine
  , validateTechCard
  , validateTechLine
  ) where

import Data.Text (Text)
import Data.Time (UTCTime)

-- | Tech card
data TechCard = TechCard
  { techCardId :: !Int
  , techCardName :: !Text
  } deriving (Show, Eq)

-- | Tech line
data TechLine = TechLine
  { techLineId :: !Int
  , techLineName :: !Text
  } deriving (Show, Eq)

-- | Validate tech card (stub)
validateTechCard :: TechCard -> Either Text ()
validateTechCard _ = Right ()

-- | Validate tech line (stub)
validateTechLine :: TechLine -> Either Text ()
validateTechLine _ = Right ()

-- | Create tech card (stub)
createTechCard :: TechCard -> UTCTime -> Text -> IO (Either Text TechCard)
createTechCard techCard _ _ = return $ Right techCard

-- | Create tech line (stub)
createTechLine :: TechLine -> UTCTime -> Text -> IO (Either Text TechLine)
createTechLine techLine _ _ = return $ Right techLine
