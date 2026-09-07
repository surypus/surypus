-- | Project module - Project management (Phase 1: stub)
module Production.Project where

import Data.Int (Int64)
import Data.Text (Text)

-- | Project
data Project = Project
  { prjId :: !Int64
  , prjName :: !Text
  , prjStatus :: !Text
  , prjCreatedAt :: !Int64
  } deriving (Show, Eq)

-- | Create a new project (stub)
createProject :: Text -> IO Project
createProject name = return $ Project 0 name "draft" 0

-- | Get project status (stub)
getProjectStatus :: Project -> Text
getProjectStatus = prjStatus

-- | Update project status (stub)
updateProjectStatus :: Project -> Text -> Project
updateProjectStatus p status = p { prjStatus = status }
