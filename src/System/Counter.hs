-- | Counter module - Counters and sequences
module System.Counter where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T

-- | Counter - Number generator
data Counter = Counter
  { cntId :: Int64,
    cntName :: Text,
    cntPrefix :: Text,
    cntSuffix :: Text,
    cntPadding :: Int,
    cntLastValue :: Int
  }
  deriving (Show, Eq)

-- | Generate next counter value
nextCounterValue :: Counter -> Text
nextCounterValue c =
  let num = show (cntLastValue c + 1)
      padded = replicate (cntPadding c - length num) '0' <> num
   in cntPrefix c `T.append` T.pack padded `T.append` cntSuffix c
