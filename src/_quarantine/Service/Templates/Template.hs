-- | Template module - Document templates
module Service.Templates.Template where

import Data.Int (Int64)
import Data.Text (Text)

-- | Template - Document template
data Template = Template
  { tplId :: Int64,
    tplName :: Text,
    tplObjectType :: Int64,
    tplContent :: Text, -- Template content
    tplEngine :: TemplateEngine
  }
  deriving (Show, Eq)

data TemplateEngine = TEBuiltIn | TEHandlebars | TEMustache
  deriving (Show, Eq)

-- | TemplateVariable - Template variable
data TemplateVariable = TemplateVariable
  { tvId :: Int64,
    tvTemplateId :: Int64,
    tvName :: Text,
    tvType :: Text,
    tvDefault :: Maybe Text
  }
  deriving (Show, Eq)
