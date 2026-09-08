{-# LANGUAGE OverloadedStrings #-}

-- | Structured JSON logging module using katip
module Surypus.API.Logger (
    LogLevel (..),
    LogField,
    Logger,
    initLogger,
    logMessage,
    logDebug,
    logInfo,
    logWarn,
    logError,
    withCorrelationId,
    getCorrelationId,
    logDBQuery,
) where

import Control.Monad (when)
import Data.Aeson (object, (.=))
import qualified Data.Aeson as A
import Data.Aeson.Key (fromText)
import Data.IORef
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (formatTime, defaultTimeLocale)
import qualified Data.ByteString.Lazy.Char8 as LBC
import qualified Katip as K
import qualified Katip.Scribes.Handle as KS
import System.IO (stdout, hFlush)

data LogLevel = Debug | Info | Warn | Error deriving (Show, Eq, Ord, Enum, Bounded)

type LogField = (String, String)

data Logger = Logger
    { loggerLevel :: LogLevel
    , loggerCorrId :: IORef (Maybe String)
    , katipEnv :: K.LogEnv
    }

initLogger :: LogLevel -> IO Logger
initLogger level = do
    corrId <- newIORef Nothing
    le <- K.initLogEnv "Surypus" "production"
    -- Use fast-logger backend (text format for stdout)
    let permitFunc :: K.Item a -> IO Bool
        permitFunc _ = return True
    scribe <- KS.mkHandleScribe KS.ColorIfTerminal stdout permitFunc K.V2
    le' <- K.registerScribe "stdout" scribe K.defaultScribeSettings le
    pure $ Logger level corrId le'

levelToKatip :: LogLevel -> K.Severity
levelToKatip Debug = K.DebugS
levelToKatip Info  = K.InfoS
levelToKatip Warn  = K.WarningS
levelToKatip Error = K.ErrorS

logKatip :: Logger -> LogLevel -> String -> [LogField] -> IO ()
logKatip logger lvl msg fields = do
    mCorrId <- readIORef (loggerCorrId logger)
    let ns = K.Namespace ["surypus"]
        severity = levelToKatip lvl
        msgWithCorr = case mCorrId of
            Just cid -> msg ++ " [correlation_id=" ++ cid ++ "]"
            Nothing  -> msg
        logAction = K.logMsg ns severity (K.logStr (T.pack msgWithCorr))
    K.runKatipT (katipEnv logger) logAction

logMessage :: Logger -> LogLevel -> String -> [LogField] -> IO ()
logMessage logger lvl msg fields =
    when (lvl >= loggerLevel logger) $
        logKatip logger lvl msg fields

logDebug :: Logger -> String -> [LogField] -> IO ()
logDebug logger msg fields = logMessage logger Debug msg fields

logInfo :: Logger -> String -> [LogField] -> IO ()
logInfo logger msg fields = logMessage logger Info msg fields

logWarn :: Logger -> String -> [LogField] -> IO ()
logWarn logger msg fields = logMessage logger Warn msg fields

logError :: Logger -> String -> [LogField] -> IO ()
logError logger msg fields = logMessage logger Error msg fields

withCorrelationId :: Logger -> String -> IO a -> IO a
withCorrelationId logger cid action = do
    old <- readIORef (loggerCorrId logger)
    writeIORef (loggerCorrId logger) (Just cid)
    result <- action
    writeIORef (loggerCorrId logger) old
    return result

getCorrelationId :: Logger -> IO (Maybe String)
getCorrelationId logger = readIORef (loggerCorrId logger)

logDBQuery :: Logger -> String -> [LogField] -> IO ()
logDBQuery logger query fields =
    logMessage logger Debug ("DB: " ++ query) fields