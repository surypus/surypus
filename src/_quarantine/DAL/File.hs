-- | File module - Files
module DAL.File  where

import Data.Int (Int64)
import Data.List (isSuffixOf)

-- | File - File
data File = File
  { fId :: Int64,
    fName :: String,
    fPath :: String,
    fSize :: Int64,
    fMimeType :: String
  }
  deriving (Show, Eq)

-- | Get extension - returns file extension including dot (e.g., ".pdf")
getExtension :: File -> String
getExtension f =
  case reverse (fName f) of
    '.' : rest -> '.': takeWhile (== '.') rest
    _ -> ""
