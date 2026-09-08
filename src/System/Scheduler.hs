module System.Scheduler where

import Control.Concurrent (forkIO, killThread, threadDelay, ThreadId)
import Control.Concurrent.STM (TVar, TQueue, atomically, isEmptyTQueue, modifyTVar, newTQueueIO, newTVarIO, readTVar, readTVarIO, readTQueue, writeTVar, writeTQueue)
import Control.Monad (forever, when)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Sequence (Seq)
import Data.Time.Calendar (Day, addDays)
import Data.Time.Clock (UTCTime(UTCTime), utctDay, addUTCTime, getCurrentTime, secondsToDiffTime)
import System.Random (randomRIO)

-- | Scheduled job types
data JobType
  = -- | Run once at specific time
    OneTime UTCTime
  | -- | Recurring schedule function
    Recurring (Day -> Bool)
  | -- | Run every N seconds
    Interval Int

instance Show JobType where
  show (OneTime t) = "OneTime " ++ show t
  show (Recurring _) = "Recurring <fn>"
  show (Interval n) = "Interval " ++ show n

instance Eq JobType where
  OneTime t1 == OneTime t2 = t1 == t2
  Recurring _ == Recurring _ = True
  Interval n1 == Interval n2 = n1 == n2
  _ == _ = False

-- | Job definition
data ScheduledJob = ScheduledJob
  { jobId :: Int,
    jobType :: JobType,
    jobAction :: IO (),
    jobNextRun :: UTCTime,
    jobEnabled :: Bool
  }

-- | Scheduler configuration
data SchedulerConfig = SchedulerConfig
  { -- | Check interval in milliseconds
    schedulerTickInterval :: Int,
    -- | Maximum number of scheduled jobs
    schedulerMaxJobs :: Int
  }

-- | Scheduler state
data Scheduler = Scheduler
  { schedulerQueue :: TQueue ScheduledJob,
    schedulerJobs :: TVar (Map UTCTime [ScheduledJob]),
    schedulerConfig :: SchedulerConfig,
    schedulerThreads :: TVar [ThreadId]
  }

-- | Initialize scheduler
initScheduler :: SchedulerConfig -> IO Scheduler
initScheduler config = do
  queue <- newTQueueIO
  jobs <- newTVarIO Map.empty
  threads <- newTVarIO []
  return $ Scheduler queue jobs config threads

-- | Schedule a one-time job
scheduleOnce :: Scheduler -> UTCTime -> IO () -> IO Int
scheduleOnce scheduler time action = do
  jobId <- randomRIO (1 :: Int, maxBound :: Int)
  let job =
        ScheduledJob
          { jobId = jobId,
            jobType = OneTime time,
            jobAction = action,
            jobNextRun = time,
            jobEnabled = True
          }
  atomically $ writeTQueue (schedulerQueue scheduler) job
  updateJobQueue scheduler job
  return jobId

-- | Schedule a recurring job
scheduleRecurring :: Scheduler -> Day -> (Day -> Bool) -> IO () -> IO Int
scheduleRecurring scheduler startDate condition action = do
  jobId <- randomRIO (1 :: Int, maxBound :: Int)
  let nextRun = calculateNextRun startDate condition
      job =
        ScheduledJob
          { jobId = jobId,
            jobType = Recurring condition,
            jobAction = action,
            jobNextRun = nextRun,
            jobEnabled = True
          }
  atomically $ writeTQueue (schedulerQueue scheduler) job
  updateJobQueue scheduler job
  return jobId

-- | Calculate next run time for recurring job
calculateNextRun :: Day -> (Day -> Bool) -> UTCTime
calculateNextRun startDate condition =
    let go d = if condition d then d else go (addDays 1 d)
        nextDay = go startDate
    in  UTCTime nextDay (secondsToDiffTime 0)

-- | Update job map
updateJobQueue :: Scheduler -> ScheduledJob -> IO ()
updateJobQueue scheduler job = atomically $ do
  jobs <- readTVar (schedulerJobs scheduler)
  let key = jobNextRun job
      newJobs = Map.insertWith (++) key [job] jobs
  writeTVar (schedulerJobs scheduler) newJobs

-- | Run the scheduler main loop
runScheduler :: Scheduler -> IO ()
runScheduler scheduler = do
  forever $ do
    now <- getCurrentTime
    dueJobs <- atomically $ do
      jobs <- readTVar (schedulerJobs scheduler)
      let (due, rem1) = Map.split now jobs
          (_, exact, rem2) = Map.splitLookup now rem1
          dueJobsList = concat (Map.elems due) ++ maybe [] id exact
      writeTVar (schedulerJobs scheduler) rem2
      return dueJobsList
    -- Execute due jobs
    mapM_ (executeJob scheduler) dueJobs
    threadDelay (schedulerTickInterval (schedulerConfig scheduler) * 1000)

-- | Execute a single job
executeJob :: Scheduler -> ScheduledJob -> IO ()
executeJob scheduler job = do
  when (jobEnabled job) $ do
    jobAction job
    -- Reschedule if recurring
    case jobType job of
      Recurring condition -> do
        currentDay <- utctDay <$> getCurrentTime
        let newTime = calculateNextRun currentDay condition
        atomically $ modifyTVar (schedulerJobs scheduler) (Map.insertWith (++) newTime [job])
      _ -> return ()
