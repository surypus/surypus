-- | Combo module - Combo deals
module Commerce.Combo  where

import Data.Int (Int64)

-- | Combo - Combo deal
data Combo = Combo
  { cmbId :: Int64,
    cmbCode :: String,
    cmbName :: String,
    cmbDiscount :: Double,
    cmbMinQty :: Int
  }
  deriving (Show, Eq)

-- | Get discount
getComboDiscount :: Combo -> Double
getComboDiscount = cmbDiscount
