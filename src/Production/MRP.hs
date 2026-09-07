{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Production.MRP
  ( BOMLine   (..),
    MRPDemand   (..),
    calculateMRP,
    calculateMRPWithInventory,
    explodeBOM
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Map.Strict as M
import Data.Foldable (foldl')
import Production.Types (TechLine  (..))

data BOMLine = BOMLine
  { bomGoodsId :: Int64,
    bomQuantity :: Double,
    bomScrapFactor :: Double
  }
  deriving (Show, Eq)

-- | Material Requirements Planning demand
newtype MRPDemand = MRPDemand
  { unMRPDemand :: [(Int64, Double)]  -- (goodsId, quantity)
  } deriving stock (Show, Eq)
    deriving newtype (Semigroup, Monoid)

-- | Calculate gross requirements from BOM and product demand
calculateMRP :: [BOMLine] -> MRPDemand -> MRPDemand
calculateMRP bomLines (MRPDemand demand) =
  MRPDemand $ M.toList $ M.filter (> 0) $ 
    foldl' (\acc (goodsId, qty) -> 
             M.insertWith (+) goodsId qty $ 
               M.unionsWith (+) [acc, 
                 M.fromList [(bomGoodsId line, qty * bomQuantity line * (1 + bomScrapFactor line)) 
                           | line <- bomLines]]) 
          M.empty demand

-- | Calculate net requirements considering current inventory and scheduled receipts
calculateMRPWithInventory :: [BOMLine] -> MRPDemand -> MRPDemand -> [(Int64, Double)] -> MRPDemand
calculateMRPWithInventory bomLines grossDemand inventory scheduledReceipts =
   let netRequirements = subtractLists 
                         (unMRPDemand $ calculateMRP bomLines grossDemand) 
                         ((unMRPDemand inventory) ++ scheduledReceipts)
   in MRPDemand $ filter ((> 0) . snd) netRequirements

-- | Explode a BOM to get all components required for a given quantity
explodeBOM :: [BOMLine] -> Int64 -> Double -> [(Int64, Double)]
explodeBOM bomLines parentId parentQty =
  concatMap (\(BOMLine {..}) -> 
              [(bomGoodsId, parentQty * bomQuantity * (1 + bomScrapFactor)) | 
               bomGoodsId /= parentId]) bomLines
  where
    -- Prevent infinite recursion in case of circular BOMs (though this simple version doesn't detect cycles)
    -- In production, we'd need cycle detection

-- | Helper to subtract two lists of (itemId, quantity)
subtractLists :: [(Int64, Double)] -> [(Int64, Double)] -> [(Int64, Double)]
subtractLists required available = 
  M.toList $ 
    M.filterWithKey (\_ qty -> qty > 0) $
    M.unionWith (-) 
      (M.fromListWith (+) required) 
      (M.fromListWith (+) available)
