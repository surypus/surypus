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

-- | Generate next number.
--
-- The increment is the sequence's configured 'seqStep' (not a hardcoded 1):
-- a sequence configured with a step of 5 must yield 5, 10, 15…, not 1, 2, 3….
-- The step is applied as-is and may be negative; a step of 0 yields no
-- movement. 'seqFlags' carries no defined bits anywhere in the codebase and
-- is deliberately ignored here.
nextNumber :: Sequence -> Text
nextNumber s =
  seqPrefix s
    `T.append` T.pack (show (seqLastNum s + seqStep s))
    `T.append` seqSuffix s
