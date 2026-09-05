{-@ LIQUID "--no-termination" @-}

-- | Temporary cash check accumulator inspired by AddTempCheckAmounts.
module Commerce.CashSessionTemp
  ( TempCashCheck,
    TempCheckLine,
    emptyTempCashCheck,
    mkTempCheckLine,
    addTempCheckLine,
    totalAmount,
    totalDiscount,
    netAmount,
    verifyCheck
  ) where

import Data.Int (Int64)

{-@ type NonNeg = {v:Double | v >= 0} @-}

{-@ data TempCheckLine = TempCheckLine
      { tclLineId   :: Int64
      , tclAmount   :: NonNeg
      , tclDiscount :: NonNeg
      }
  @-}
data TempCheckLine = TempCheckLine
  { tclLineId :: Int64,
    tclAmount :: Double,
    tclDiscount :: Double
  }
  deriving (Eq, Show)

{-@ mkTempCheckLine :: Int64 -> NonNeg -> NonNeg -> Maybe TempCheckLine @-}
mkTempCheckLine :: Int64 -> Double -> Double -> Maybe TempCheckLine
mkTempCheckLine lineId amount discount
  | amount >= discount = Just $ TempCheckLine lineId amount discount
  | otherwise = Nothing

{-@ data TempCashCheck = TempCashCheck
      { tchCheckId    :: Int64
      , tchRegisterId :: Int64
      , tchLines      :: [TempCheckLine]
      }
  @-}
data TempCashCheck = TempCashCheck
  { tchCheckId :: Int64,
    tchRegisterId :: Int64,
    tchLines :: [TempCheckLine]
  }
  deriving (Eq, Show)

-- | Create an empty accumulator for a check.
emptyTempCashCheck :: Int64 -> Int64 -> TempCashCheck
emptyTempCashCheck checkId regId =
  TempCashCheck {tchCheckId = checkId, tchRegisterId = regId, tchLines = []}

-- | Append a validated line to the temporary check.
addTempCheckLine :: TempCashCheck -> TempCheckLine -> TempCashCheck
addTempCheckLine check line =
  check {tchLines = line : tchLines check}

{-@ totalAmount :: TempCashCheck -> NonNeg @-}
totalAmount :: TempCashCheck -> Double
totalAmount = foldr (\l acc -> tclAmount l + acc) 0 . tchLines

{-@ totalDiscount :: TempCashCheck -> NonNeg @-}
totalDiscount :: TempCashCheck -> Double
totalDiscount = foldr (\l acc -> tclDiscount l + acc) 0 . tchLines

{-@ netAmount :: TempCashCheck -> NonNeg @-}
netAmount :: TempCashCheck -> Double
netAmount check =
  let diff = totalAmount check - totalDiscount check
   in max diff 0

-- | Verify that the accumulated amounts obey the invariant (total >= discount).
verifyCheck :: TempCashCheck -> Bool
verifyCheck check = totalAmount check >= totalDiscount check
