-- | Project module - Project management
module Production.Project  where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime, utctDay, getCurrentTime)
import qualified Data.Map.Strict as Map
import Control.Concurrent.STM (TVar, newTVarIO, readTVar, readTVarIO, writeTVar, atomically)
import System.Validation (ValidationError  (..))

-- | Project - Project
data Project = Project
  { prjId :: Int64,
    prjCode :: Text,
    prjName :: Text,
    prjStartDate :: Day,
    prjEndDate :: Maybe Day,
    prjBudget :: Double,
    prjStatus :: ProjectStatus
  }
  deriving (Show, Eq)

data ProjectStatus = PSPlanned | PSInProgress | PSCompleted | PSCancelled | PSHold
  deriving (Show, Eq)

-- | Project priority
data ProjectPriority = PPLow | PPMedium | PPHigh | PPCritical
  deriving (Show, Eq, Ord)

-- | Project manager
data ProjectManager = ProjectManager
  { pmId :: Int64,
    pmName :: Text,
    pmEmail :: Text,
    pmDepartment :: Text
  }
  deriving (Show, Eq)

-- | Extended project with additional fields
data ExtendedProject = ExtendedProject
  { epProject :: Project,
    epManager :: Maybe ProjectManager,
    epPriority :: ProjectPriority,
    epTags :: [Text],
    epCreatedAt :: UTCTime,
    epUpdatedAt :: UTCTime,
    epProgress :: Double  -- 0.0 to 1.0
  }
  deriving (Show, Eq)

-- | Task - Project task
data Task = Task
  { tskId :: Int64,
    tskProjectId :: Int64,
    tskName :: Text,
    tskParentId :: Maybe Int64,
    tskStartDate :: Day,
    tskEndDate :: Maybe Day,
    tskStatus :: TaskStatus,
    tskAssignedTo :: Maybe Int64,
    tskEstimatedHours :: Maybe Double,
    tskActualHours :: Maybe Double,
    tskDescription :: Text
  }
  deriving (Show, Eq)

data TaskStatus = TSTodo | TSInProgress | TSDone | TSBlocked | TSReview
  deriving (Show, Eq)

-- | Project repository
data ProjectRepository = ProjectRepository
  { prProjects :: TVar (Map.Map Int64 ExtendedProject),
    prTasks :: TVar (Map.Map Int64 Task),
    prNextId :: TVar Int64
  }

-- | Initialize project repository
initProjectRepository :: IO ProjectRepository
initProjectRepository = do
  projectsVar <- newTVarIO Map.empty
  tasksVar <- newTVarIO Map.empty
  nextIdVar <- newTVarIO 1
  return $ ProjectRepository projectsVar tasksVar nextIdVar

-- | Create project
createProject :: ProjectRepository -> ExtendedProject -> IO (Either [ValidationError] ExtendedProject)
createProject repo project = do
  now <- getCurrentTime
  let validatedProject = project { epCreatedAt = now, epUpdatedAt = now }
  case validateProject validatedProject of
    Left errs -> return $ Left errs
    Right _ -> do
      newProject <- atomically $ do
        projects <- readTVar (prProjects repo)
        nextId <- readTVar (prNextId repo)
        let newId = nextId
            newProject = validatedProject { epProject = (epProject validatedProject) { prjId = newId } }
            updatedProjects = Map.insert newId newProject projects
        writeTVar (prProjects repo) updatedProjects
        writeTVar (prNextId repo) (nextId + 1)
        return newProject
      return $ Right newProject

-- | Get project by ID
getProject :: ProjectRepository -> Int64 -> IO (Maybe ExtendedProject)
getProject repo projectId = do
  projects <- readTVarIO (prProjects repo)
  return $ Map.lookup projectId projects

-- | Update project
updateProject :: ProjectRepository -> Int64 -> ExtendedProject -> IO (Either [ValidationError] ExtendedProject)
updateProject repo projectId project = do
  now <- getCurrentTime
  let updatedProject = project { epUpdatedAt = now }
  case validateProject updatedProject of
    Left errs -> return $ Left errs
    Right _ -> do
      atomically $ do
        projects <- readTVar (prProjects repo)
        case Map.lookup projectId projects of
          Nothing -> return ()
          Just _ -> do
            let finalProject = updatedProject { epProject = (epProject updatedProject) { prjId = projectId } }
            writeTVar (prProjects repo) (Map.insert projectId finalProject projects)
      return $ Right updatedProject

-- | Delete project
deleteProject :: ProjectRepository -> Int64 -> IO Bool
deleteProject repo projectId = do
  atomically $ do
    projects <- readTVar (prProjects repo)
    case Map.lookup projectId projects of
      Nothing -> return False
      Just _ -> do
        writeTVar (prProjects repo) (Map.delete projectId projects)
        -- Also delete all tasks for this project
        tasks <- readTVar (prTasks repo)
        let projectTasks = Map.filter (\task -> tskProjectId task == projectId) tasks
            taskIds = Map.keys projectTasks
        writeTVar (prTasks repo) (foldr Map.delete tasks taskIds)
        return True

-- | List all projects
listProjects :: ProjectRepository -> IO [ExtendedProject]
listProjects repo = do
  projects <- readTVarIO (prProjects repo)
  return $ Map.elems projects

-- | Validate project
validateProject :: ExtendedProject -> Either [ValidationError] ExtendedProject
validateProject project =
  let baseProject = epProject project
      errors = concat [
        maybe [] (const [RequiredFieldMissing (T.pack "code")]) $ if T.null (prjCode baseProject) then Nothing else Just (),
        maybe [] (const [RequiredFieldMissing (T.pack "name")]) $ if T.null (prjName baseProject) then Nothing else Just (),
        if prjBudget baseProject < 0 then [CustomError (T.pack "Budget cannot be negative")] else [],
        if epProgress project < 0 || epProgress project > 1
        then [CustomError (T.pack "Progress must be between 0 and 1")]
        else []]
  in if null errors
     then Right project
     else Left errors

-- | Check if project is overdue
isProjectOverdue :: Project -> Day -> Bool
isProjectOverdue prj today = case prjEndDate prj of
  Nothing -> False
  Just ed -> today > ed

-- | Get project statistics
getProjectStats :: ProjectRepository -> IO ProjectStats
getProjectStats repo = do
   projectsMap <- readTVarIO (prProjects repo)
   currentDay <- utctDay <$> getCurrentTime
   let projects = Map.elems projectsMap
       totalProjects = length projects
       completedProjects = length $ filter (\p -> prjStatus (epProject p) == PSCompleted) projects
       inProgressProjects = length $ filter (\p -> prjStatus (epProject p) == PSInProgress) projects
       overdueProjects = length $ filter (\p -> isProjectOverdue (epProject p) currentDay) projects
       totalBudget = sum $ map (prjBudget . epProject) projects
   return $ ProjectStats {
     psTotal = totalProjects,
     psCompleted = completedProjects,
     psInProgress = inProgressProjects,
     psOverdue = overdueProjects,
     psTotalBudget = totalBudget
   }

-- | Project statistics
data ProjectStats = ProjectStats
  { psTotal :: Int,
    psCompleted :: Int,
    psInProgress :: Int,
    psOverdue :: Int,
    psTotalBudget :: Double
  }
  deriving (Show, Eq)
