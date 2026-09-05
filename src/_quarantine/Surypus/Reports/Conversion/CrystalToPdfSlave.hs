-- | PDF Slave conversion
module Surypus.Reports.Conversion.CrystalToPdfSlave where

import Data.Text (Text)
import Surypus.Reports.Conversion.CrystalTypes

data PdfSlaveMeta = PdfSlaveMeta
  { pmTitle :: Text
  }
  deriving (Show, Eq)

data PdfSlaveTemplate = PdfSlaveTemplate
  { ptMeta :: PdfSlaveMeta
  }
  deriving (Show, Eq)

convertCrystalToPdfSlave :: CrystalReport -> PdfSlaveTemplate
convertCrystalToPdfSlave report =
  PdfSlaveTemplate
    { ptMeta = PdfSlaveMeta {pmTitle = crName report}
    }