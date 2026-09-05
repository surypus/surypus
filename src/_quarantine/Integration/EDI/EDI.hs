-- | EDI module - Electronic data interchange
module Integration.EDI.EDI where

import Data.Int (Int64)
import Data.Time (Day)

-- | EDIExchange - EDI exchange
data EDIExchange = EDIExchange
  { ediId :: Int64,
    ediProviderId :: Int64,
    ediType :: EDIType,
    ediDirection :: EDIDirection,
    ediStatus :: EDIStatus,
    ediDate :: Day,
    ediDocId :: Int64
  }
  deriving (Show, Eq)

data EDIType = EDIOrder | EDIInvoice | EDIDesadv | EDIRecadv
  deriving (Show, Eq)

data EDIDirection = EDIDIncoming | EDIDOutgoing
  deriving (Show, Eq)

data EDIStatus = EDISPending | EDISSent | EDISReceived | EDISAccepted | EDISRejected
  deriving (Show, Eq)
