-- | Sequence module - Number generators
module System.Sequence where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T

-- | Sequence - Number sequence
data Sequence = Sequence
  { seqId :: Int64,
    seqName :: Text,
    seqPrefix :: Text,
    seqSuffix :: Text,
    seqLastNum :: Int,
    seqStep :: Int,
    seqFlags :: Int
  }
  deriving (Show, Eq)

-- | Generate next number
nextNumber :: Sequence -> Text
nextNumber s = seqPrefix s `T.append` T.pack (show (seqLastNum s + 1)) `T.append` seqSuffix s
