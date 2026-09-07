-- | Barcode module - Barcode processing
module Inventory.Barcode where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T

-- | Barcode structure
data Barcode = Barcode
  { bcId :: Int64,
    bcCode :: Text,
    bcGoodsId :: Int64,
    bcUnitId :: Int64,
    bcQty :: Double,
    bcFlags :: Int
  }
  deriving (Show, Eq)

-- | Barcode structure definition
data BCodeStruc = BCodeStruc
  { bcsId :: Int64,
    bcsName :: Text,
    bcsFormat :: BarcodeFormat,
    bcsMask :: Text
  }
  deriving (Show, Eq)

data BarcodeFormat = BF_EAN13 | BF_EAN8 | BF_UPC | BF_QR | BF_Code128
  deriving (Show, Eq)

-- | Validate barcode checksum (EAN-13) - simplified
validateEAN13 :: Text -> Bool
validateEAN13 ean = T.length ean == 13
