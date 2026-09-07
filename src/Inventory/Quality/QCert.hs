-- | QCert module - Quality certificates
module Inventory.Quality.QCert where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | QCert - Quality certificate
data QCert = QCert
  { qcId :: Int64,
    qcNumber :: Text,
    qcGoodsId :: Int64,
    qcCertType :: CertType,
    qcIssueDate :: Day,
    qcExpiryDate :: Maybe Day,
    qcOrgName :: Text
  }
  deriving (Show, Eq)

data CertType = CTQuality | CTPhytosanitary | CTVeterinary | CTExplosive
  deriving (Show, Eq)

-- | Check if certificate is valid
isQCertValid :: QCert -> Day -> Bool
isQCertValid qc today =
  today >= qcIssueDate qc
    && case qcExpiryDate qc of
      Nothing -> True
      Just expd -> today <= expd
