-- | Package module - Product packaging
module Commerce.Package  where

import Data.Int (Int64)
import Data.Text (Text)

-- | PackageType - Type of product package
data PackageType = PTBox | PTPallet | PTBundle | PTPiece
  deriving (Show, Eq)

-- | Package - Product package
data Package = Package
  { pkgId :: Int64,
    pkgCode :: Text,
    pkgType :: PackageType,
    pkgWeight :: Double,
    pkgVolume :: Double,
    pkgDimensions :: Text, -- LxWxH
    pkgBarcode :: Text
  }
  deriving (Show, Eq)

-- | Pallet - Shipping pallet
data Pallet = Pallet
  { palId :: Int64,
    palCode :: Text,
    palLocationId :: Int64,
    palStatus :: PalletStatus,
    palWeight :: Double
  }
  deriving (Show, Eq)

data PalletStatus = PSEmpty | PSLoading | PSLoaded | PSShipped
  deriving (Show, Eq)
