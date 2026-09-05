-- | SheetDiffs module - Sheet differences
module Finance.SheetDiffs where

import Data.Int (Int64)

-- | SheetDiffs - Sheet differences
data SheetDiffs = SheetDiffs
  { sdId :: Int64,
    sdSheetId :: Int64,
    sdDate :: Int64,
    sdDebit :: Double,
    sdCredit :: Double
  }
  deriving (Show, Eq)

-- | Is balanced
isBalanced :: SheetDiffs -> Bool
isBalanced sd = abs (sdDebit sd - sdCredit sd) < 0.01
