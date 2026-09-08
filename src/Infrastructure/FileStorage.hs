module Infrastructure.FileStorage where

import Control.Exception (IOException, try)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BSL
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time.Clock (UTCTime, getCurrentTime)
import Data.Bits (xor)
import qualified System.Directory as Dir
import qualified System.FilePath as FP
import System.FilePath (takeDirectory)
import System.IO (IOMode   (..), hGetContents, hPutStr, withFile)
import Data.List (isSuffixOf)

-- | File storage configuration
data StorageConfig = StorageConfig
  { storageBasePath :: FilePath,
    storageMaxSize :: Integer,
    storageAllowedTypes :: [String]
  }

-- | File metadata
data FileMetadata = FileMetadata
  { filePath :: FilePath,
    fileSize :: Integer,
    fileType :: String,
    uploadTime :: UTCTime,
    fileHash :: String,
    metadata :: Map.Map Text Text
  }

-- | Initialize storage with base path
initStorage :: FilePath -> IO StorageConfig
initStorage basePath = do
  Dir.createDirectoryIfMissing True basePath
  return
    StorageConfig
      { storageBasePath = basePath,
        storageMaxSize = 104857600, -- 100MB
        storageAllowedTypes = [".png", ".jpg", ".pdf", ".txt"]
      }

-- | Save file with metadata
saveFile :: StorageConfig -> FilePath -> BS.ByteString -> IO (Either String FileMetadata)
saveFile config filename content = do
  let fullPath = storageBasePath config FP.</> filename
  let fileSize' = fromIntegral (BS.length content)
  allowed <-
    return $
      fileSize' <= storageMaxSize config
        && any (FP.takeExtension filename ==) (storageAllowedTypes config)
  if not allowed
    then return $ Left "File type or size not allowed"
    else do
      Dir.createDirectoryIfMissing True (takeDirectory fullPath)
      BS.writeFile fullPath content
      time <- getCurrentTime
      let hash = show (BS.foldl' xor 0 content)
      return $
        Right
          FileMetadata
            { filePath = fullPath,
              fileSize = fileSize',
              fileType = FP.takeExtension filename,
              uploadTime = time,
              fileHash = hash,
              metadata = Map.empty
            }

-- | Read file content
readFileContent :: FilePath -> IO (Either String BS.ByteString)
readFileContent path = do
  result <- try (BS.readFile path) :: IO (Either IOException BS.ByteString)
  case result of
    Left err -> return $ Left $ show err
    Right content -> return $ Right content

-- | Delete file
deleteFile :: FilePath -> IO (Either String ())
deleteFile path = do
  result <- try (Dir.removeFile path) :: IO (Either IOException ())
  case result of
    Left err -> return $ Left $ show err
    Right () -> return $ Right ()

-- | List files in directory
listFiles :: FilePath -> IO [FilePath]
listFiles path = do
  exists <- Dir.doesDirectoryExist path
  if exists
    then Dir.getDirectoryContents path
    else return []

-- | Calculate file hash (simplified)
calculateHash :: BS.ByteString -> String
calculateHash = show . BS.foldl' xor 0

-- | Validate file type
validateFileType :: FilePath -> [FilePath] -> Bool
validateFileType filename allowed =
  any (isSuffixOf filename) allowed
