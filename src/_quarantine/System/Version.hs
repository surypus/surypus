-- | Version module - Version control
module System.Version where

import Data.Int (Int64)
import Data.Text (Text)

-- | Version - Object version
data Version = Version
  { verId :: Int64,
    verObjectType :: Int64,
    verObjectId :: Int64,
    verNumber :: Int,
    verData :: Text, -- JSON
    verCreatedAt :: Int64,
    verUserId :: Int64
  }
  deriving (Show, Eq)

-- | VersionDiff - Version comparison
data VersionDiff = VersionDiff
  { vdFromVerId :: Int64,
    vdToVerId :: Int64,
    vdChanges :: Text -- JSON diff
  }
  deriving (Show, Eq)
