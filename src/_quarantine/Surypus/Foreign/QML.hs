{-# LANGUAGE DeriveGeneric #-}

module Surypus.Foreign.QML
  ( QMLMessage(..)
  , QMLNotifType(..)
  , QMLCommand(..)
  , CRUDAction(..)
  , QueryFilters(..)
  , SortDir(..)
  , PageResponse(..)
  , ExportFormat(..)
  , EmailMessage(..)
  , EmailAttachment(..)
  , TemplateRef(..)
  , TemplateEngine(..)
  ) where

import Data.Aeson (ToJSON, FromJSON, Value)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Calendar (Day)
import GHC.Generics (Generic)
import Data.UUID (UUID)
import qualified Data.Map.Strict as M

data QMLMessage
  = QMLModelUpdate    { qmModel :: !Text, qmData :: !Value }
  | QMLNavigation     { qmRoute :: !Text, qmParams :: !(Maybe Value) }
  | QMLNotification   { qmType :: !QMLNotifType, qmText :: !Text }
  | QMLDialogOpen     { qmDialog :: !Text, qmEntity :: !(Maybe Value) }
  | QMLSyncComplete   { qmEntityType :: !Text, qmCount :: !Int }
  | QMLError          { qmCode :: !Text, qmMessage :: !Text }
  deriving (Generic, Show, Eq)

data QMLNotifType
  = QMLNotifInfo
  | QMLNotifSuccess
  | QMLNotifWarning
  | QMLNotifError
  deriving (Generic, Show, Eq)

data QMLCommand
  = QMLCRUD           { qcAction :: !CRUDAction, qcEntity :: !Text, qcPayload :: !Value }
  | QMLQuery          { qcQuery :: !Text, qcFilters :: !(Maybe QueryFilters) }
  | QMLExport         { qcEntity :: !Text, qcFormat :: !ExportFormat }
  | QMLImport         { qcSessionId :: !UUID }
  | QMLScanBarcode    { qcBarcode :: !Text }
  | QMLSendEmail      { qcEmail :: !EmailMessage }
  deriving (Generic, Show, Eq)

data CRUDAction
  = Create
  | Read
  | Update
  | Delete
  deriving (Generic, Show, Eq)

data QueryFilters = QueryFilters
  { qfSearch   :: !(Maybe Text)
  , qfStatus   :: !(Maybe Text)
  , qfDateFrom :: !(Maybe Day)
  , qfDateTo   :: !(Maybe Day)
  , qfSortBy   :: !(Maybe Text)
  , qfSortDir  :: !(Maybe SortDir)
  } deriving (Generic, Show, Eq)

data SortDir = SortAsc | SortDesc
  deriving (Generic, Show, Eq)

data PageResponse a = PageResponse
  { prData     :: ![a]
  , prTotal    :: !Int64
  , prPage     :: !Int
  , prPageSize :: !Int
  , prPages    :: !Int
  } deriving (Generic, Show, Eq)

data ExportFormat
  = EFCSV
  | EFXLSX
  | EFPDF
  | EFHTML
  | EFJSON
  | EFXML
  deriving (Generic, Show, Eq)

data EmailMessage = EmailMessage
  { emTo          :: !Text
  , emSubject     :: !Text
  , emBody        :: !Text
  , emAttachments :: ![EmailAttachment]
  , emTemplate    :: !(Maybe TemplateRef)
  } deriving (Generic, Show, Eq)

data EmailAttachment = EmailAttachment
  { eaFileName :: !Text
  , eaMimeType :: !Text
  , eaContent  :: !String
  } deriving (Generic, Show, Eq)

data TemplateRef = TemplateRef
  { trName   :: !Text
  , trEngine :: !TemplateEngine
  , trParams :: !(M.Map Text Value)
  } deriving (Generic, Show, Eq)

data TemplateEngine
  = TEHandlebars
  | TEMustache
  | TEJinja2
  | TEPdfSlave
  deriving (Generic, Show, Eq)

instance ToJSON QMLMessage
instance FromJSON QMLMessage
instance ToJSON QMLNotifType
instance FromJSON QMLNotifType
instance ToJSON QMLCommand
instance FromJSON QMLCommand
instance ToJSON CRUDAction
instance FromJSON CRUDAction
instance ToJSON QueryFilters
instance FromJSON QueryFilters
instance ToJSON SortDir
instance FromJSON SortDir
instance ToJSON a => ToJSON (PageResponse a)
instance FromJSON a => FromJSON (PageResponse a)
instance ToJSON ExportFormat
instance FromJSON ExportFormat
instance ToJSON EmailMessage
instance FromJSON EmailMessage
instance ToJSON EmailAttachment
instance FromJSON EmailAttachment
instance ToJSON TemplateRef
instance FromJSON TemplateRef
instance ToJSON TemplateEngine
instance FromJSON TemplateEngine
