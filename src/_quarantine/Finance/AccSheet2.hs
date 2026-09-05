-- | AccSheet2 module - Extended accounting sheets
module Finance.AccSheet2 where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T

-- | AccSheet2 - Extended accounting sheet
data AccSheet2 = AccSheet2
  { as2Id :: Int64,
    as2Code :: Text,
    as2Name :: Text,
    as2Type :: AccSheetType,
    as2Flags :: Int
  }
  deriving (Show, Eq)

data AccSheetType = AstAssets | AstLiabilities | AstIncome | AstExpenses
  deriving (Show, Eq)

-- | Get sheet type name
getSheetTypeName :: AccSheet2 -> Text
getSheetTypeName a = case as2Type a of
  AstAssets -> T.pack "Assets"
  AstLiabilities -> T.pack "Liabilities"
  AstIncome -> T.pack "Income"
  AstExpenses -> T.pack "Expenses"
