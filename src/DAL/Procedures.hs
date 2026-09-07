-- | DAL Procedures (Phase 1: stub)
module DAL.Procedures where

import Data.Int (Int64)
import Data.Text (Text)
import DAL.Types
import DAL.Database (ConnectionPool)

-- | Run stored procedure (stub)
runProcedure :: ConnectionPool -> Text -> [Text] -> IO (QueryResult [Text])
runProcedure _ _ _ = return $ QueryResult [] 0

-- | Call stored function (stub)
callFunction :: ConnectionPool -> Text -> [Text] -> IO (QueryResult Text)
callFunction _ _ _ = return $ QueryResult [] 0
