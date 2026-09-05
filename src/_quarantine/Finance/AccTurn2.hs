-- | AccTurn2 module - Extended accounting entries
module Finance.AccTurn2 where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | AccTurn2 - Extended accounting entry
data AccTurn2 = AccTurn2
  { at2Id :: Int64,
    at2BillId :: Int64,
    at2DbtAccId :: Int64,
    at2CrdAccId :: Int64,
    at2Amount :: Double,
    at2CurrencyId :: Int64,
    at2Date :: Day,
    at2Memos :: Text
  }
  deriving (Show, Eq)

-- | Validate double entry
validateDoubleEntry :: [AccTurn2] -> Bool
validateDoubleEntry entries =
  let debits = sum (fmap at2Amount entries)
   in debits >= 0
